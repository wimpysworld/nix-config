import { readFile } from "node:fs/promises";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { ImageContent, TextContent } from "@earendil-works/pi-ai";
import { Box, Text } from "@earendil-works/pi-tui";

const ENTRY_TYPE = "prompt-template-command";
const MESSAGE_TYPE = "prompt-template-expanded";

interface CommandEntry {
	command: string;
}

interface ExpandedMarker {
	command: string;
}

interface PendingPrompt {
	command: string;
	expansion: string;
}

function parseCommandArgs(argsString: string): string[] {
	const args: string[] = [];
	let current = "";
	let inQuote: string | null = null;

	for (const char of argsString) {
		if (inQuote) {
			if (char === inQuote) inQuote = null;
			else current += char;
		} else if (char === '"' || char === "'") inQuote = char;
		else if (/\s/.test(char)) {
			if (current) {
				args.push(current);
				current = "";
			}
		} else current += char;
	}

	if (current) args.push(current);
	return args;
}

function substituteArgs(content: string, args: string[]): string {
	const allArgs = args.join(" ");

	return content.replace(
		/\$\{(\d+|ARGUMENTS|@):-([^}]*)\}|\$\{@:(\d+)(?::(\d+))?\}|\$(ARGUMENTS|@|\d+)/g,
		(_match, defaultTarget, defaultValue, sliceStart, sliceLength, simple) => {
			if (defaultTarget) {
				const value =
					defaultTarget === "@" || defaultTarget === "ARGUMENTS"
						? allArgs
						: args[Number.parseInt(defaultTarget, 10) - 1];
				return value || defaultValue;
			}

			if (sliceStart) {
				const start = Math.max(Number.parseInt(sliceStart, 10) - 1, 0);
				if (sliceLength) {
					return args
						.slice(start, start + Number.parseInt(sliceLength, 10))
						.join(" ");
				}
				return args.slice(start).join(" ");
			}

			if (simple === "ARGUMENTS" || simple === "@") return allArgs;
			return args[Number.parseInt(simple, 10) - 1] ?? "";
		},
	);
}

function templateBody(content: string): string {
	const normalized = content.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
	if (!normalized.startsWith("---")) return normalized;

	const endIndex = normalized.indexOf("\n---", 3);
	if (endIndex === -1) return normalized;
	return normalized.slice(endIndex + 4).trim();
}

export default function registerPromptTemplateDisplay(pi: ExtensionAPI): void {
	let pending: PendingPrompt | undefined;

	pi.registerEntryRenderer<CommandEntry>(
		ENTRY_TYPE,
		(entry, _options, theme) => {
			const box = new Box(1, 1, (text) => theme.bg("userMessageBg", text));
			box.addChild(
				new Text(theme.fg("userMessageText", entry.data?.command ?? ""), 0, 0),
			);
			return box;
		},
	);

	pi.on("before_agent_start", async (event) => {
		const current = pending;
		pending = undefined;
		if (!current || event.prompt !== current.command) return;

		return {
			message: {
				customType: MESSAGE_TYPE,
				content: current.expansion,
				display: false,
				details: { command: current.command } satisfies ExpandedMarker,
			},
		};
	});

	pi.on("context", async (event) => {
		const messages = [...event.messages];

		for (
			let markerIndex = messages.length - 1;
			markerIndex >= 0;
			markerIndex--
		) {
			const marker = messages[markerIndex];
			if (marker.customType !== MESSAGE_TYPE) continue;

			const command = (marker.details as ExpandedMarker | undefined)?.command;
			if (typeof command !== "string" || typeof marker.content !== "string") {
				continue;
			}

			let userIndex = markerIndex - 1;
			while (userIndex >= 0 && messages[userIndex].role !== "user") userIndex--;
			if (userIndex < 0) continue;

			const userMessage = messages[userIndex];
			const images =
				typeof userMessage.content === "string"
					? []
					: userMessage.content.filter((part) => part.type === "image");
			messages[userIndex] = {
				...userMessage,
				content: [{ type: "text", text: marker.content }, ...images],
			};
			messages.splice(markerIndex, 1);
		}

		return { messages };
	});

	pi.on("input", async (event, ctx) => {
		if (
			ctx.mode !== "tui" ||
			event.source === "extension" ||
			!event.text.startsWith("/")
		) {
			return { action: "continue" };
		}

		const invocation = event.text.match(/^\/([^\s]+)(?:\s+([\s\S]*))?$/);
		if (!invocation) return { action: "continue" };

		const command = pi
			.getCommands()
			.find((item) => item.source === "prompt" && item.name === invocation[1]);
		if (!command || command.sourceInfo.source === "sdk") {
			return { action: "continue" };
		}

		if (event.streamingBehavior) {
			pi.appendEntry<CommandEntry>(ENTRY_TYPE, { command: event.text });
		}

		let source: string;
		try {
			source = await readFile(command.sourceInfo.path, "utf8");
		} catch (error) {
			if (!event.streamingBehavior) {
				pi.appendEntry<CommandEntry>(ENTRY_TYPE, { command: event.text });
			}
			const reason = error instanceof Error ? error.message : String(error);
			ctx.ui.notify(
				`Could not read prompt template ${command.sourceInfo.path}: ${reason}`,
				"error",
			);
			return { action: "handled" };
		}

		const expanded = substituteArgs(
			templateBody(source),
			parseCommandArgs(invocation[2] ?? ""),
		);
		if (event.streamingBehavior) {
			const content: (TextContent | ImageContent)[] = [
				{ type: "text", text: expanded },
				...(event.images ?? []),
			];
			pi.sendMessage(
				{
					customType: MESSAGE_TYPE,
					content,
					display: false,
				},
				{ deliverAs: event.streamingBehavior },
			);
		} else {
			pending = { command: event.text, expansion: expanded };
			pi.sendUserMessage([
				{ type: "text", text: event.text },
				...(event.images ?? []),
			]);
		}

		return { action: "handled" };
	});
}
