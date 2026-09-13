import assert from "node:assert/strict";
import {
	mkdtempSync,
	mkdirSync,
	writeFileSync,
	rmSync,
	symlinkSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { after, test } from "node:test";

const packageDir =
	process.env.PI_SUBAGENTS_DIR ??
	join(homedir(), ".pi/agent/npm/node_modules/@tintinweb/pi-subagents");
const { runWorkflow, validateScript, WORKFLOW_AGENT_CAP } = await import(
	pathToFileURL(join(packageDir, "src/workflow/runtime.ts")).href
);
const fixtureHome = mkdtempSync(join(tmpdir(), "provider-router-test-"));
after(() => rmSync(fixtureHome, { recursive: true, force: true }));
const mapDir = join(fixtureHome, ".pi/agent/extensions/provider-router");
mkdirSync(mapDir, { recursive: true });
writeFileSync(
	join(mapDir, "agents.json"),
	JSON.stringify({
		worker: { "openai-codex": "test-model" },
	}),
);
writeFileSync(
	join(mapDir, "thinking.json"),
	JSON.stringify({
		worker: { "openai-codex": "high" },
	}),
);
writeFileSync(
	join(mapDir, "routes.json"),
	JSON.stringify({
		commands: {
			review: {
				agent: "worker",
				providers: {
					"openai-codex": { model: "command-model", thinking: "medium" },
				},
			},
			missing: { providers: { "openai-codex": { model: "unavailable-model" } } },
			foreign: { providers: { anthropic: { model: "claude-sonnet-5" } } },
		},
		skills: {
			focused: {
				providers: { "openai-codex": { model: "skill-model", thinking: "low" } },
			},
		},
	}),
);
const originalHome = process.env.HOME;
let registerProviderRouter;
try {
	process.env.HOME = fixtureHome;
	({ default: registerProviderRouter } = await import("./index.ts"));
} finally {
	if (originalHome === undefined) delete process.env.HOME;
	else process.env.HOME = originalHome;
}

function route(input, provider = "openai-codex", toolName = "Agent") {
	const handlers = new Map();
	registerProviderRouter({
		on: (name, handler) => handlers.set(name, handler),
		events: { on: () => () => {}, emit: () => {} },
	});
	const result = handlers.get("tool_call")(
		{ toolName, input },
		{
			cwd: fixtureHome,
			model: { provider, id: "parent-model" },
			modelRegistry: {
				getAvailable: () =>
					[
						"test-model",
						"command-model",
						"skill-model",
						"explicit-model",
						"parent-model",
					].map((id) => ({ provider: "openai-codex", id })),
			},
		},
	);
	if (result?.block) throw new Error(result.reason);
	return input;
}

const meta =
	'export const meta = {name: "Router test", description: "Test native routes", phases: [{title: "Check"}]};';
async function execute(body, options = {}) {
	const input = route(
		{ script: `${meta}\n${body}`, ...options.input },
		options.provider,
		"SubagentWorkflow",
	);
	assert.equal(validateScript(input.script).meta.name, "Router test");
	const calls = [];
	let running = 0;
	let peak = 0;
	const result = await runWorkflow({
		script: input.script,
		args: { marker: "kept" },
		concurrency: 16,
		signal: AbortSignal.timeout(5000),
		host: {
			spawnAgent: async (request) => {
				calls.push(request);
				peak = Math.max(peak, ++running);
				await new Promise((resolve) => setTimeout(resolve, 5));
				running--;
				return options.fail
					? { ok: false, error: "test failure" }
					: { ok: true, text: request.prompt };
			},
			resumeAgent: async (_id, prompt) => ({ ok: true, text: prompt }),
			abortAgent: () => {},
		},
	});
	return { calls, result, peak };
}

test("routes Agent with separate model and thinking fields", () => {
	const result = route({
		subagent_type: "worker",
		description: "Check",
		prompt: "direct",
		inherit_context: false,
		run_in_background: true,
	});
	assert.equal(result.model, "openai-codex/test-model");
	assert.equal(result.thinking, "high");
	assert.equal(result.inherit_context, false);
	assert.equal(result.run_in_background, true);
	assert.equal(result.prompt, "direct");
});

test("preserves explicit, foreground, and inherited-context requests", () => {
	const result = route({
		subagent_type: "worker",
		model: "openai-codex/explicit-model",
		thinking: "low",
		inherit_context: true,
		run_in_background: false,
	});
	assert.equal(result.model, "openai-codex/explicit-model");
	assert.equal(result.thinking, "low");
	assert.equal(result.inherit_context, true);
	assert.equal(result.run_in_background, false);
	assert.equal(
		route({ subagent_type: "worker", model: "explicit-model:medium" }).thinking,
		"medium",
	);
});

test("command and directly invoked skill routes override agent routes", () => {
	const result = route({ subagent_type: "worker", command: "review" });
	assert.equal(result.model, "openai-codex/command-model");
	assert.equal(result.thinking, "medium");
	assert.ok(!("command" in result));
	assert.equal(
		route({ subagent_type: "worker", directSkill: "focused" }).model,
		"openai-codex/skill-model",
	);
	assert.equal(
		route({ subagent_type: "worker", command: "review", model: "explicit-model" })
			.model,
		"openai-codex/explicit-model",
	);
});

test("supporting skill reads and result tools do not select models", () => {
	const read = { path: "/skills/focused/SKILL.md" };
	assert.deepEqual(route({ ...read }, undefined, "read"), read);
	const result = { agent_id: "child" };
	assert.deepEqual(
		route({ ...result }, undefined, "get_subagent_result"),
		result,
	);
	assert.equal(
		route({ subagent_type: "worker", skills: true }).model,
		"openai-codex/test-model",
	);
});

test("unknown routes, unavailable models, and unsupported thinking block launches", () => {
	for (const input of [
		{ command: "unknown" },
		{ directSkill: "unknown" },
		{ command: "missing" },
		{ command: "foreign" },
		{ model: "anthropic/claude-sonnet-5" },
		{ thinking: "max" },
	])
		assert.throws(
			() => route({ subagent_type: "worker", ...input }),
			/provider-router:/,
		);
	assert.throws(() => route({ prompt: "missing type" }), /explicit specialist/);
});

test("unsafe worktrees, isolated policy bypasses, and schedules are rejected", () => {
	for (const input of [
		{ isolation: "worktree" },
		{ isolated: true },
		{ extensions: false },
		{ schedule: "+5m" },
	])
		assert.throws(
			() => route({ subagent_type: "worker", ...input }),
			/provider-router:/,
		);
});

test("resume retains the existing child contract", () => {
	const input = { resume: "child", prompt: "Continue", run_in_background: true };
	assert.deepEqual(route({ ...input }), input);
});

test("native parallel workflow queues above twelve and routes every child", async () => {
	const keys = Array.from({ length: 15 }, (_, n) => String(n));
	const { calls, result, peak } = await execute(
		`return await parallel(${JSON.stringify(keys)}.map(key => () => agent(key, {agentType: "worker"})));`,
	);
	assert.equal(result.status, "completed", result.error);
	assert.deepEqual(result.value, keys);
	assert.equal(peak, 12);
	assert.equal(calls.length, keys.length);
	assert.ok(
		calls.every(
			(call) => call.model === "openai-codex/test-model" && call.effort === "high",
		),
	);
});

test("native sequential and pipeline workflows preserve values and args", async () => {
	const { calls, result } = await execute(`
const first = await agent(args.marker, {agentType: "worker"});
return await pipeline([first], value => agent(value + "-second", {agentType: "worker", model: "explicit-model", effort: "low"}));`);
	assert.equal(result.status, "completed", result.error);
	assert.deepEqual(result.value, ["kept-second"]);
	assert.equal(calls[1].model, "openai-codex/explicit-model");
	assert.equal(calls[1].effort, "low");
});

test("workflow routes strip routing-only fields before the native API", async () => {
	const { calls, result } = await execute(
		`return await agent("review", {agentType: "worker", command: "review"});`,
	);
	assert.equal(result.status, "completed", result.error);
	assert.equal(calls[0].model, "openai-codex/command-model");
	assert.equal(calls[0].effort, "medium");
	assert.ok(!("command" in calls[0]));
});

test("missing agent types and failed required children cannot report success", async () => {
	for (const [body, fail] of [
		['return await agent("missing type");', false],
		['return await agent("failure", {agentType: "worker"});', true],
		[
			'try { await agent("invalid", {agentType: "worker", command: "missing"}); } catch {} return "hidden";',
			false,
		],
		['return await parallel([() => {throw new Error("stage");}]);', false],
		['return await pipeline(["a"], () => {throw new Error("stage");});', false],
		[
			'return await agent("unsafe", {agentType: "worker", isolation: "worktree"});',
			false,
		],
		['return await workflow("unrouted");', false],
	]) {
		const { result } = await execute(body, { fail });
		assert.equal(result.status, "failed", body);
	}
});

test("workflows accept more than 64 calls", async () => {
	const { result, calls } = await execute(
		'for (let n = 0; n < 65; n++) await agent(String(n), {agentType: "worker"}); return "done";',
	);
	assert.equal(result.status, "completed", result.error);
	assert.equal(result.value, "done");
	assert.equal(calls.length, 65);
});

test("native 1000-call cap remains even when the script catches errors", async () => {
	assert.equal(WORKFLOW_AGENT_CAP, 1000);
	const { result, calls } = await execute(
		'return await parallel(Array.from({length: 1001}, (_, n) => async () => { try { return await agent(String(n), {agentType: "worker"}); } catch { return "hidden"; } }));',
	);
	assert.equal(result.status, "failed");
	assert.equal(calls.length, 1000);
	assert.match(result.error, /cap of 1000 agents/);
});

test("scriptPath and saved sources receive the same routing wrapper", async () => {
	const root = join(fixtureHome, ".pi/workflows");
	mkdirSync(root, { recursive: true });
	const file = join(root, "fixture.js");
	writeFileSync(
		file,
		`${meta}\nreturn await agent("file", {agentType: "worker"});`,
	);
	for (const input of [{ scriptPath: file }, { script: "", name: "fixture" }]) {
		const { calls, result } = await execute(
			"throw new Error('wrong precedence');",
			{ input },
		);
		assert.equal(result.status, "completed", result.error);
		assert.equal(result.value, "file");
		assert.equal(calls[0].model, "openai-codex/test-model");
	}
	symlinkSync(file, join(root, "linked.js"));
	assert.throws(
		() => route({ name: "linked" }, undefined, "SubagentWorkflow"),
		/not found/,
	);
	assert.throws(
		() => route({ name: "../fixture" }, undefined, "SubagentWorkflow"),
		/safe saved/,
	);
});

test("workflow resume preserves the original specialist contract", async () => {
	const { result, calls } = await execute(`
await agent("first", {agentType: "worker", label: "review"});
return await agent("follow-up", {resume: "review"});`);
	assert.equal(result.status, "completed", result.error);
	assert.equal(result.value, "follow-up");
	assert.equal(calls.length, 1);
});

test("unawaited workflow launches cannot report completion", async () => {
	const { result } = await execute(
		'agent("unobserved", {agentType: "worker"}); return "early";',
	);
	assert.equal(result.status, "failed");
	assert.match(result.error, /unawaited/);
});

test("native workflow cancellation aborts its active mock child", async () => {
	const controller = new AbortController();
	const aborted = [];
	const input = route(
		{ script: `${meta}\nreturn await agent("wait", {agentType: "worker"});` },
		undefined,
		"SubagentWorkflow",
	);
	const result = await runWorkflow({
		script: input.script,
		signal: controller.signal,
		host: {
			spawnAgent: async () => {
				controller.abort();
				return new Promise(() => {});
			},
			abortAgent: (id) => aborted.push(id),
		},
	});
	assert.equal(result.status, "killed");
	assert.equal(aborted.length, 1);
});

test("clean findings complete without verifier launches", async () => {
	const { result, calls } = await execute(`
const findings = [];
return await parallel(findings.map(finding => () => agent(finding, {agentType: "worker"})));`);
	assert.equal(result.status, "completed", result.error);
	assert.deepEqual(result.value, []);
	assert.equal(calls.length, 0);
});

test("workflows with no provider route can return without launching children", async () => {
	const { result } = await execute("return 42;", { provider: "unknown" });
	assert.equal(result.status, "completed", result.error);
	assert.equal(result.value, 42);
});
