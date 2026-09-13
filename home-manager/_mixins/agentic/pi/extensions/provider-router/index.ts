/// <reference path="./types.d.ts" />

import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import {
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { getSupportedThinkingLevels } from "@earendil-works/pi-ai/compat";

type Route = { model?: string; thinking?: string };
type Entry = { agent?: string; providers: Record<string, Route> };
type Routes = {
	commands: Record<string, Entry>;
	skills: Record<string, Entry>;
};
type Task = Record<string, unknown>;
type State = {
	provider?: string;
	model?: string;
	agents: Record<string, Record<string, string>>;
	thinking: Record<string, Record<string, string>>;
	routes: Routes;
	available: string[];
	supportedThinking: Record<string, string[]>;
	explicitModel?: string;
	command?: string;
	directSkill?: string;
};

const directory = path.join(
	os.homedir(),
	".pi/agent/extensions/provider-router",
);

function load(name: string): any {
	try {
		const value = JSON.parse(
			fs.readFileSync(path.join(directory, name), "utf-8"),
		);
		if (!value || typeof value !== "object" || Array.isArray(value))
			throw new Error("expected an object");
		return value;
	} catch (error) {
		if ((error as { code?: string }).code === "ENOENT") return {};
		throw new Error(`provider-router: cannot load ${name}: ${String(error)}`);
	}
}

// These route functions also run in the workflow VM, without module imports.
export function resolveTaskRoute(task: Task, state: State): string | undefined {
	const fail = (message: string): never => {
		throw new Error(`provider-router: ${message}`);
	};
	const levels = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];
	const provider = state.provider;
	const entry = (
		kind: "commands" | "skills",
		name: unknown,
	): Entry | undefined => {
		if (name === undefined) return undefined;
		if (typeof name !== "string" || !Object.hasOwn(state.routes[kind], name))
			return fail(`unknown ${kind} route ${String(name)}`);
		return state.routes[kind][name];
	};
	const command = entry("commands", task.command ?? state.command);
	const skill = entry("skills", task.directSkill ?? state.directSkill);
	const agent = typeof task.agent === "string" ? task.agent : command?.agent;
	let route: Route | undefined;
	const explicitModel = task.model ?? state.explicitModel;
	if (explicitModel === undefined) {
		for (const candidate of [command, skill]) {
			if (!candidate || Object.keys(candidate.providers).length === 0) continue;
			if (!provider || !Object.hasOwn(candidate.providers, provider))
				return fail(`no route for active provider ${provider ?? "(none)"}`);
			route = candidate.providers[provider];
			break;
		}
		if (!route && agent && provider) {
			const model = state.agents[agent]?.[provider];
			const thinking = state.thinking[agent]?.[provider];
			if (model !== undefined || thinking !== undefined)
				route = { model, thinking };
		}
	} else {
		if (typeof explicitModel !== "string" || !explicitModel.trim())
			return fail("explicit model must be a non-empty string");
		const match = explicitModel.match(/^(.*?)(?::([^/:]+))?$/)!;
		let model = match[1];
		if (provider && model.startsWith(`${provider}/`))
			model = model.slice(provider.length + 1);
		route = { model, thinking: match[2] };
	}
	if (!route) return undefined;
	if (
		typeof route !== "object" ||
		Array.isArray(route) ||
		Object.keys(route).some((key) => key !== "model" && key !== "thinking")
	)
		return fail("unsupported route fields");
	if (!provider) return fail("a route requires an active inference provider");
	const model = route.model ?? state.model;
	if (typeof model !== "string" || !model.trim())
		return fail("a route requires a model");
	if (route.thinking !== undefined && !levels.includes(route.thinking))
		return fail(`unsupported thinking level ${String(route.thinking)}`);
	if (!state.available.includes(model))
		return fail(
			`model ${provider}/${model} is unavailable for the active provider`,
		);
	if (
		route.thinking !== undefined &&
		!state.supportedThinking[model]?.includes(route.thinking)
	)
		return fail(
			`model ${provider}/${model} does not support thinking level ${route.thinking}`,
		);
	return `${provider}/${model}${route.thinking === undefined ? "" : `:${route.thinking}`}`;
}

export function resolveNativeTask(
	task: Task,
	state: State,
	workflow = false,
): Task {
	const native = { ...task };
	if (native.isolation && native.isolation !== "off")
		throw new Error(
			"provider-router: automatic worktrees are unsafe in upstream 0.19.0; use a separate checkout session",
		);
	if (native.isolated === true || native.extensions === false)
		throw new Error(
			"provider-router: child policy extensions must remain enabled",
		);
	if (native.schedule !== undefined)
		throw new Error(
			"provider-router: scheduled launches bypass current routing and are disabled",
		);
	if (native.resume !== undefined) return native;
	const agent = workflow ? native.agentType : native.subagent_type;
	if (typeof agent !== "string" || !agent.trim())
		throw new Error("provider-router: name an explicit specialist agent");
	const effort = workflow ? native.effort : native.thinking;
	const normalised: Task = { ...native, agent };
	if (effort !== undefined) {
		if (typeof effort !== "string")
			throw new Error("provider-router: thinking must be a string");
		const routed = resolveTaskRoute(normalised, state);
		const model =
			routed?.replace(/:[^/:]+$/, "") ?? `${state.provider}/${state.model}`;
		normalised.model = `${model}:${effort}`;
	}
	const resolved = resolveTaskRoute(normalised, state);
	if (resolved) {
		const match = resolved.match(/^(.*?)(?::([^/:]+))?$/)!;
		native.model = match[1];
		if (match[2] !== undefined)
			native[workflow ? "effort" : "thinking"] = match[2];
	}
	delete native.command;
	delete native.directSkill;
	return native;
}

export function readWorkflow(input: Task, cwd: string): string {
	if (typeof input.scriptPath === "string" && input.scriptPath.trim())
		return fs.readFileSync(path.resolve(cwd, input.scriptPath.trim()), "utf8");
	if (typeof input.script === "string" && input.script.trim())
		return input.script;
	const name = typeof input.name === "string" ? input.name.trim() : "";
	if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(name) || name.includes(".."))
		throw new Error(
			"provider-router: supply script, scriptPath, or a safe saved workflow name",
		);
	const roots = [
		path.join(cwd, ".pi/workflows"),
		path.join(cwd, ".agents/workflows"),
		path.join(
			process.env.PI_CODING_AGENT_DIR ?? path.join(os.homedir(), ".pi/agent"),
			"workflows",
		),
	];
	for (const root of roots) {
		const file = path.join(root, `${name}.js`);
		if (!fs.existsSync(root) || fs.lstatSync(root).isSymbolicLink()) continue;
		if (!fs.existsSync(file) || fs.lstatSync(file).isSymbolicLink()) continue;
		return fs.readFileSync(file, "utf8");
	}
	throw new Error(`provider-router: saved workflow ${name} was not found`);
}

export function wrapWorkflow(script: string, state: State): string {
	return `
const __routerState = ${JSON.stringify(state)};
const resolveTaskRoute = ${resolveTaskRoute.toString()};
const resolveNativeTask = ${resolveNativeTask.toString()};
const __nativeAgent = agent;
const __nativeParallel = parallel;
const __nativePipeline = pipeline;
let __running = 0;
let __launches = 0;
let __failure;
const __waiting = [];
const __check = (value) => {
 if (value === null || (Array.isArray(value) && value.some(v => v === null))) {
  __failure ??= new Error("provider-router: a required workflow child failed or was skipped");
  throw __failure;
 }
 return value;
};
const __result = await (async () => {
 const agent = async (prompt, options = {}) => {
  try {
   if (++__launches > 64) throw new Error("provider-router: workflow launch limit is 64");
   const native = resolveNativeTask(options, __routerState, true);
   if (__running >= 2) await new Promise(resolve => __waiting.push(resolve));
   else __running++;
   try { return __check(await __nativeAgent(prompt, native)); }
   finally { const next = __waiting.shift(); if (next) next(); else __running--; }
  } catch (error) { __failure ??= error; throw error; }
 };
 const parallel = async (...args) => __check(await __nativeParallel(...args));
 const pipeline = async (...args) => __check(await __nativePipeline(...args));
 const workflow = () => {
  __failure ??= new Error("provider-router: launch saved workflows through SubagentWorkflow so routing applies");
  throw __failure;
 };
${script}
})();
if (__failure) throw __failure;
return __result;
`.trim();
}

export async function routeInvocation(
	text: string,
	ctx: ExtensionContext,
	streaming?: string,
	pi?: ExtensionAPI,
): Promise<boolean> {
	const request: {
		text: string;
		ctx: ExtensionContext;
		streaming?: string;
		result?: Promise<boolean>;
	} = { text, ctx, streaming };
	pi?.events.emit("provider-router:invoke", request);
	if (!request.result)
		throw new Error("provider-router: routing extension is not loaded");
	return request.result;
}

export default function registerProviderRouter(pi: ExtensionAPI): void {
	let maps: Pick<State, "agents" | "thinking" | "routes">;
	let loadError: unknown;
	let changing = false;
	const callerModel = process.argv.some(
		(arg) => arg === "--model" || arg.startsWith("--model="),
	);
	let explicit = callerModel;
	let abortPending = false;
	let pending:
		| {
				text: string;
				model: any;
				thinking?: string;
				command?: string;
				directSkill?: string;
		  }
		| undefined;
	let active:
		| {
				text: string;
				model: any;
				thinking: any;
				command?: string;
				directSkill?: string;
		  }
		| undefined;
	const reload = (): void => {
		try {
			const routes = load("routes.json");
			maps = {
				agents: load("agents.json"),
				thinking: load("thinking.json"),
				routes: {
					commands: routes.commands ?? {},
					skills: routes.skills ?? {},
				},
			};
			loadError = undefined;
		} catch (error) {
			loadError = error;
		}
	};
	reload();
	const stateFor = (ctx: ExtensionContext): State => {
		if (loadError) throw loadError;
		const provider = ctx.model?.provider;
		const available = ctx.modelRegistry
			.getAvailable()
			.filter((model) => model.provider === provider);
		return {
			...maps,
			provider,
			model: ctx.model?.id,
			command: active?.command,
			directSkill: active?.directSkill,
			explicitModel:
				explicit && provider && ctx.model?.id
					? `${provider}/${ctx.model.id}:${pi.getThinkingLevel()}`
					: undefined,
			available: available.map((model) => model.id),
			supportedThinking: Object.fromEntries(
				available.map((model) => [model.id, getSupportedThinkingLevels(model)]),
			),
		};
	};
	const restore = async (): Promise<void> => {
		const previous = active;
		active = undefined;
		if (!previous) return;
		changing = true;
		try {
			if (!(await pi.setModel(previous.model)))
				throw new Error("provider-router: could not restore session model");
			pi.setThinkingLevel(previous.thinking);
		} finally {
			changing = false;
		}
	};
	pi.on("session_start", () => {
		active = undefined;
		pending = undefined;
		abortPending = false;
		explicit = callerModel;
		reload();
	});
	pi.on("resources_discover", reload);
	pi.on("model_select", (event) => {
		if (!changing && event.source !== "restore") {
			explicit = true;
			active = undefined;
			pending = undefined;
			abortPending = false;
		}
	});
	pi.on("agent_settled", restore);
	pi.on("agent_start", async (_event, ctx) => {
		if (abortPending) {
			abortPending = false;
			ctx.abort();
		}
	});
	pi.on("before_agent_start", async (_event, ctx) => {
		const request = pending;
		pending = undefined;
		if (!request) return;
		active = {
			...request,
			model: ctx.model,
			thinking: pi.getThinkingLevel(),
		};
		changing = true;
		try {
			if (!(await pi.setModel(request.model)))
				throw new Error("provider-router: could not select routed model");
			if (request.thinking) {
				pi.setThinkingLevel(request.thinking);
				if (pi.getThinkingLevel() !== request.thinking)
					throw new Error("provider-router: could not select routed thinking level");
			}
		} catch (error) {
			abortPending = true;
			ctx.ui.notify(String(error), "error");
			await restore();
		} finally {
			changing = false;
		}
	});
	const dispatch = async (
		text: string,
		ctx: ExtensionContext,
		streaming?: string,
	): Promise<boolean> => {
		pending = undefined;
		abortPending = false;
		const match = text.match(/^\/(skill:)?([^\s]+)(?:\s|$)/);
		if (!match) return true;
		try {
			if (loadError) throw loadError;
			const kind = match[1] ? "skills" : "commands";
			if (!Object.hasOwn(maps.routes[kind], match[2])) return true;
			if (active?.text === text && !streaming) return true;
			const task =
				kind === "skills" ? { directSkill: match[2] } : { command: match[2] };
			if (explicit) return true;
			const state = stateFor(ctx);
			const resolved = resolveTaskRoute(task, state);
			if (!resolved) return true;
			if (streaming || !ctx.isIdle())
				throw new Error(
					"provider-router: routed commands and skills require an idle session",
				);
			const selected = resolved
				.slice(state.provider!.length + 1)
				.match(/^(.*?)(?::([^/:]+))?$/)!;
			const model = ctx.modelRegistry.find(state.provider!, selected[1]);
			if (!model)
				throw new Error(`provider-router: model ${resolved} is unavailable`);
			pending = {
				text,
				model,
				thinking: selected[2],
				...task,
			};
			return true;
		} catch (error) {
			ctx.ui.notify(String(error), "error");
			return false;
		}
	};
	const unsubscribe = pi.events.on("provider-router:invoke", (request: any) => {
		request.result = dispatch(request.text, request.ctx, request.streaming);
	});
	pi.on("session_shutdown", unsubscribe);
	pi.on("input", async (event, ctx) => ({
		action: (await dispatch!(event.text, ctx, event.streamingBehavior))
			? "continue"
			: "handled",
	}));
	pi.on("tool_call", (event, ctx) => {
		if (event.toolName !== "Agent" && event.toolName !== "SubagentWorkflow")
			return;
		const input = event.input as Task;
		try {
			const state = stateFor(ctx);
			if (event.toolName === "SubagentWorkflow") {
				input.script = wrapWorkflow(readWorkflow(input, ctx.cwd), state);
				delete input.scriptPath;
				delete input.name;
			} else {
				const native = resolveNativeTask(input, state);
				for (const key of Object.keys(input)) delete input[key];
				Object.assign(input, native);
			}
		} catch (error) {
			return { block: true, reason: String(error) };
		}
	});
}
