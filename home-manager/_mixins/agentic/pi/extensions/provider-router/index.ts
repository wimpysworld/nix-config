/// <reference path="./types.d.ts" />

import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import {
	isToolCallEventType,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

type AgentModelMap = Record<string, Record<string, string>>;
type AgentThinkingMap = Record<string, Record<string, string>>;

interface RoutedTask {
	agent?: unknown;
	model?: unknown;
}

interface RoutedChainStep extends RoutedTask {
	parallel?: unknown;
}

type SubagentToolInput = Record<string, unknown> &
	RoutedTask & {
		action?: unknown;
		tasks?: unknown;
		chain?: unknown;
	};

const mapFile = path.join(
	os.homedir(),
	".pi/agent/extensions/provider-router/agents.json",
);
const thinkingFile = path.join(
	os.homedir(),
	".pi/agent/extensions/provider-router/thinking.json",
);

const VALID_THINKING_LEVELS = new Set<string>([
	"off",
	"minimal",
	"low",
	"medium",
	"high",
	"xhigh",
]);

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

function toAgentThinkingMap(value: unknown): AgentThinkingMap {
	if (!isRecord(value)) return {};

	const result: AgentThinkingMap = Object.create(null);
	for (const [agent, providerLevels] of Object.entries(value)) {
		if (!isRecord(providerLevels)) continue;

		const levels: Record<string, string> = Object.create(null);
		for (const [provider, level] of Object.entries(providerLevels)) {
			if (typeof level === "string" && VALID_THINKING_LEVELS.has(level)) {
				levels[provider] = level;
			}
		}

		if (Object.keys(levels).length > 0) {
			result[agent] = levels;
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

function loadThinkingMap(): AgentThinkingMap {
	try {
		return toAgentThinkingMap(
			JSON.parse(fs.readFileSync(thinkingFile, "utf-8")),
		);
	} catch {
		return {};
	}
}

function applyModel(
	task: RoutedTask,
	provider: string | undefined,
	map: AgentModelMap,
	thinkingMap: AgentThinkingMap,
	ctx: ExtensionContext,
): void {
	if (typeof task.agent !== "string" || !provider) return;

	const mappedModel = map[task.agent]?.[provider];
	const thinking = thinkingMap[task.agent]?.[provider];

	// Known-agent gate: only act when the agent has at least one routing entry
	// (model or thinking) for the active provider. Unknown agents pass through.
	if (mappedModel === undefined && thinking === undefined) return;

	// Pick the bare model id. Prefer an explicit model-<provider> override; if
	// only a thinking-<provider> entry exists, fall back to the active session
	// model so we can attach the effort suffix without changing the model.
	let bareModel: string | undefined;
	if (mappedModel) {
		bareModel = mappedModel;
	} else if (
		thinking &&
		typeof ctx.model?.id === "string" &&
		ctx.model.id.length > 0
	) {
		bareModel = ctx.model.id;
	}

	if (!bareModel) return;

	// Validate against the unsuffixed model id only. The thinking suffix is
	// Pi-specific routing syntax and must never reach modelRegistry.find.
	if (!ctx.modelRegistry.find(provider, bareModel)) return;

	const routedModel = thinking
		? `${provider}/${bareModel}:${thinking}`
		: `${provider}/${bareModel}`;

	// Log when the extension overrides an orchestrator-supplied value. The
	// common case (orchestrator left model unset) emits nothing.
	if (typeof task.model === "string" && task.model !== routedModel) {
		console.error(
			`provider-router: override model for agent=${task.agent} orchestrator=${task.model} -> routed=${routedModel}`,
		);
	}

	task.model = routedModel;
}

export default function registerProviderRouter(pi: ExtensionAPI): void {
	let map = loadMap();
	let thinkingMap = loadThinkingMap();
	const reloadMaps = (): void => {
		map = loadMap();
		thinkingMap = loadThinkingMap();
	};

	pi.on("session_start", reloadMaps);
	pi.on("resources_discover", reloadMaps);

	pi.on("tool_call", (event, ctx) => {
		if (!isToolCallEventType<"subagent", SubagentToolInput>("subagent", event))
			return;

		const input = event.input;
		if (input.action && input.action !== "append-step") return;

		const provider = ctx.model?.provider;
		applyModel(input, provider, map, thinkingMap, ctx);

		if (Array.isArray(input.tasks)) {
			for (const task of input.tasks) {
				if (isRecord(task)) {
					applyModel(task, provider, map, thinkingMap, ctx);
				}
			}
		}

		if (Array.isArray(input.chain)) {
			for (const step of input.chain) {
				if (!isRecord(step)) continue;

				const chainStep = step as RoutedChainStep;
				applyModel(chainStep, provider, map, thinkingMap, ctx);

				if (Array.isArray(chainStep.parallel)) {
					for (const parallelTask of chainStep.parallel) {
						if (isRecord(parallelTask)) {
							applyModel(parallelTask, provider, map, thinkingMap, ctx);
						}
					}
				} else if (isRecord(chainStep.parallel)) {
					applyModel(chainStep.parallel, provider, map, thinkingMap, ctx);
				}
			}
		}
	});
}
