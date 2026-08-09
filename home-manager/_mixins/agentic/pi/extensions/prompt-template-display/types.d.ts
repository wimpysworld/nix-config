declare module "node:fs/promises" {
	export function readFile(path: string, encoding: "utf8"): Promise<string>;
}

declare module "@earendil-works/pi-ai" {
	export interface TextContent {
		type: "text";
		text: string;
	}

	export interface ImageContent {
		type: "image";
		data: string;
		mimeType: string;
	}
}

declare module "@earendil-works/pi-tui" {
	export class Box {
		constructor(
			paddingX: number,
			paddingY: number,
			background: (text: string) => string,
		);
		addChild(child: Text): void;
	}

	export class Text {
		constructor(text: string, paddingX: number, paddingY: number);
	}
}

declare module "@earendil-works/pi-coding-agent" {
	import type { ImageContent, TextContent } from "@earendil-works/pi-ai";
	import type { Box } from "@earendil-works/pi-tui";

	interface Theme {
		bg(name: "userMessageBg", text: string): string;
		fg(name: "userMessageText", text: string): string;
	}

	interface PromptCommand {
		name: string;
		source: "extension" | "prompt" | "skill";
		sourceInfo: { path: string; source: string };
	}

	interface AgentMessage {
		role?: string;
		customType?: string;
		content: string | (TextContent | ImageContent)[];
		details?: unknown;
	}

	interface ContextEvent {
		messages: AgentMessage[];
	}

	interface BeforeAgentStartEvent {
		prompt: string;
		images?: ImageContent[];
	}

	interface InputEvent {
		text: string;
		images?: ImageContent[];
		source: "interactive" | "rpc" | "extension";
		streamingBehavior?: "steer" | "followUp";
	}

	interface ExtensionContext {
		mode: "tui" | "rpc" | "json" | "print";
		ui: { notify(message: string, level: "error" | "info" | "warning"): void };
	}

	export interface ExtensionAPI {
		appendEntry<T>(customType: string, data: T): void;
		getCommands(): PromptCommand[];
		on(
			event: "input",
			handler: (
				event: InputEvent,
				context: ExtensionContext,
			) => Promise<{ action: "continue" | "handled" }>,
		): void;
		on(
			event: "before_agent_start",
			handler: (
				event: BeforeAgentStartEvent,
				context: ExtensionContext,
			) => Promise<
				| {
						message: {
							customType: string;
							content: string | (TextContent | ImageContent)[];
							display: boolean;
							details?: unknown;
						};
				  }
				| undefined
			>,
		): void;
		on(
			event: "context",
			handler: (
				event: ContextEvent,
				context: ExtensionContext,
			) => Promise<{ messages: AgentMessage[] }>,
		): void;
		registerEntryRenderer<T>(
			customType: string,
			renderer: (
				entry: { data?: T },
				options: { expanded: boolean },
				theme: Theme,
			) => Box,
		): void;
		sendMessage(
			message: {
				customType: string;
				content: string | (TextContent | ImageContent)[];
				display: boolean;
				details?: unknown;
			},
			options?: {
				triggerTurn?: boolean;
				deliverAs?: "steer" | "followUp" | "nextTurn";
			},
		): void;
		sendUserMessage(
			content: string | (TextContent | ImageContent)[],
			options?: { deliverAs: "steer" | "followUp" },
		): void;
	}
}
