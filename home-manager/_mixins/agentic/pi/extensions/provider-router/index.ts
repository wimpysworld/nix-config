import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import { isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";

type AgentModelMap = Record<string, Record<string, string>>;

interface RoutedTask {
	agent?: unknown;
	model?: unknown;
}

interface RoutedChainStep extends RoutedTask {
	parallel?: unknown;
}

type SubagentToolInput = Record<string, unknown> & RoutedTask & {
	action?: unknown;
	tasks?: unknown;
	chain?: unknown;
};

const mapFile = path.join(os.homedir(), ".pi/agent/extensions/provider-router/agents.json");

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function toAgentModelMap(value: unknown): AgentModelMap {
	if (!isRecord(value)) return {};

	const result: AgentModelMap = Object.create(null);
	for (const [agent, providerModels] of Object.entries(value)) {
		if (!isRecord(providerModels)) continue;

		const models: Record<string, string> = Object.create(null);
		for (const [provider, modelId] of Object.entries(providerModels)) {
			if (typeof modelId === "string" && modelId.length > 0) {
				models[provider] = modelId;
			}
		}

		if (Object.keys(models).length > 0) {
			result[agent] = models;
		}
	}

	return result;
}

function loadMap(): AgentModelMap {
	try {
		return toAgentModelMap(JSON.parse(fs.readFileSync(mapFile, "utf-8")));
	} catch {
		return {};
	}
}

function hasUnsetModel(task: RoutedTask): boolean {
	return task.model === undefined;
}

function applyModel(task: RoutedTask, provider: string | undefined, map: AgentModelMap, ctx: ExtensionContext): void {
	if (typeof task.agent !== "string" || !hasUnsetModel(task) || !provider) return;

	const candidate = map[task.agent]?.[provider];
	if (!candidate) return;

	// Only rewrite to models Pi reports as available for this authenticated session.
	if (ctx.modelRegistry.find(provider, candidate)) {
		task.model = `${provider}/${candidate}`;
	}
}

export default function registerProviderRouter(pi: ExtensionAPI): void {
	let map = loadMap();
	const reloadMap = (): void => {
		map = loadMap();
	};

	pi.on("session_start", reloadMap);
	pi.on("resources_discover", reloadMap);

	pi.on("tool_call", (event, ctx) => {
		if (!isToolCallEventType<"subagent", SubagentToolInput>("subagent", event)) return;

		const input = event.input;
		if (input.action) return;

		const provider = ctx.model?.provider;
		applyModel(input, provider, map, ctx);

		if (Array.isArray(input.tasks)) {
			for (const task of input.tasks) {
				if (isRecord(task)) {
					applyModel(task, provider, map, ctx);
				}
			}
		}

		if (Array.isArray(input.chain)) {
			for (const step of input.chain) {
				if (!isRecord(step)) continue;

				const chainStep = step as RoutedChainStep;
				applyModel(chainStep, provider, map, ctx);

				if (Array.isArray(chainStep.parallel)) {
					for (const parallelTask of chainStep.parallel) {
						if (isRecord(parallelTask)) {
							applyModel(parallelTask, provider, map, ctx);
						}
					}
				}
			}
		}
	});
}
