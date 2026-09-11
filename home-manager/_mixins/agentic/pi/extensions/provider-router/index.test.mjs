import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { after, test } from "node:test";

const packageDir = process.env.PI_SUBAGENTS_DIR
	?? join(homedir(), ".pi/agent/npm/node_modules/pi-subagents");
const { runWorkflowScript, validateWorkflowScript } = await import(
	pathToFileURL(join(packageDir, "src/workflows/scripted-workflow.ts")).href
);

const fixtureHome = mkdtempSync(join(tmpdir(), "provider-router-test-"));
after(() => rmSync(fixtureHome, { recursive: true, force: true }));
const mapDir = join(fixtureHome, ".pi/agent/extensions/provider-router");
mkdirSync(mapDir, { recursive: true });
writeFileSync(join(mapDir, "agents.json"), JSON.stringify({
	worker: { "openai-codex": "test-model" },
}));
writeFileSync(join(mapDir, "thinking.json"), JSON.stringify({
	worker: { "openai-codex": "high" },
}));
writeFileSync(join(mapDir, "routes.json"), JSON.stringify({
	commands: {
		review: { agent: "worker", providers: { "openai-codex": { model: "command-model", thinking: "medium" } } },
		missing: { providers: { "openai-codex": { model: "unavailable-model" } } },
		foreign: { providers: { anthropic: { model: "claude-sonnet-5" } } },
	},
	skills: { focused: { providers: { "openai-codex": { model: "skill-model", thinking: "low" } } } },
}));
const originalHome = process.env.HOME;
let registerProviderRouter;
try {
	process.env.HOME = fixtureHome;
	({ default: registerProviderRouter } = await import("./index.ts"));
} finally {
	if (originalHome === undefined) delete process.env.HOME;
	else process.env.HOME = originalHome;
}

function route(input, provider = "openai-codex", options = {}) {
	const handlers = new Map();
	registerProviderRouter({ on: (name, handler) => handlers.set(name, handler), events: { on: () => () => {}, emit: () => {} } });
	const result = handlers.get("tool_call")({ toolName: options.toolName ?? "subagent", input }, {
		model: { provider, id: "parent-model" },
		modelRegistry: {
			getAvailable: () => ["test-model", "command-model", "skill-model", "explicit-model", "parent-model"]
				.map((id) => ({ provider: "openai-codex", id })),
		},
	});
	if (result?.block) throw new Error(result.reason);
	return input;
}

function childResult(key, params = {}) {
	return { key, runId: `test-${key}`, ok: true, output: params.task ?? key, artifactPaths: [] };
}

async function execute(script, provider = "openai-codex") {
	const input = route({ workflowScript: script }, provider);
	assert.deepEqual(validateWorkflowScript(input.workflowScript), { ok: true, errors: [] });
	const calls = [];
	const result = await runWorkflowScript({
		script: input.workflowScript,
		timeoutMs: 5000,
		launch: async (key, params) => {
			calls.push({ key, ...params });
			return childResult(key, params);
		},
		status: async (key) => childResult(key),
	});
	return { calls, result };
}

test("routes a top-level parallel workflow without nested async functions", async () => {
	const { calls, result } = await execute(`
const specs = ['a', 'b'].map((key) => ({ key, agent: 'worker', task: key }));
return await runs.all(specs);
`);
	assert.equal(calls.length, 2);
	assert.deepEqual(calls.map(({ key, model }) => ({ key, model })), [
		{ key: "a", model: "openai-codex/test-model:high" },
		{ key: "b", model: "openai-codex/test-model:high" },
	]);
	assert.deepEqual(result.value.map(({ output }) => output), ["a", "b"]);
});

test("routes sequential children and preserves explicit return values", async () => {
	const { calls, result } = await execute(`
const first = await runs.run('first', {agent: 'worker', task: 'first'});
return (await runs.run('second', {agent: 'worker', task: first.output + '-second'})).output;
`);
	assert.equal(result.value, "first-second");
	assert.ok(calls.every(({ model }) => model === "openai-codex/test-model:high"));
});

test("preserves an explicit model ahead of the agent route", async () => {
	const { calls } = await execute(`
return await runs.all([
  {key: 'known', agent: 'worker', task: 'known', model: 'openai-codex/explicit-model'},
  {key: 'unknown', agent: 'unmapped', task: 'unknown', model: 'openai-codex/explicit-model'}
]);
`);
	assert.equal(calls[0].model, "openai-codex/explicit-model");
	assert.equal(calls[1].model, "openai-codex/explicit-model");
});

test("preserves other workflow methods and global helpers", async () => {
	const { result } = await execute(`
const child = await runs.run('child', {agent: 'worker', task: 'child'});
const status = await runs.status('child');
emit('complete');
return {output: status.output, steer: typeof runs.steer, ref: typeof runs.ref, refs: typeof runs.refs};
`);
	assert.deepEqual(result.value, { output: "test-child", steer: "function", ref: "function", refs: "function" });
	assert.deepEqual(result.emits, ["complete"]);
});

test("preserves workflow results when the provider has no route", async () => {
	const { result, calls } = await execute("return 42;", "unknown");
	assert.equal(result.value, 42);
	assert.deepEqual(calls, []);
});

test("keeps management calls unchanged and routes direct children", () => {
	const validation = { action: "validate", workflowScript: "return 42;" };
	assert.deepEqual(route({ ...validation }), validation);
	assert.equal(route({ agent: "worker", task: "direct" }).model, "openai-codex/test-model:high");
});

test("routes parallel and chain children with the same precedence", () => {
	const result = route({
		tasks: [{ agent: "worker", command: "review" }, { agent: "worker", model: "openai-codex/explicit-model" }],
		chain: [{ agent: "worker" }, { parallel: [{ agent: "worker", command: "review" }] }],
	});
	assert.equal(result.tasks[0].model, "openai-codex/command-model:medium");
	assert.equal(result.tasks[1].model, "openai-codex/explicit-model");
	assert.equal(result.chain[0].model, "openai-codex/test-model:high");
	assert.equal(result.chain[1].parallel[0].model, "openai-codex/command-model:medium");
});

test("command routing overrides agent defaults but not explicit caller choices", () => {
	assert.equal(route({ agent: "worker", command: "review" }).model, "openai-codex/command-model:medium");
	assert.equal(route({ agent: "worker", command: "review", model: "openai-codex/explicit-model" }).model,
		"openai-codex/explicit-model");
});

test("supporting skills and file reads do not select a model", () => {
	assert.equal(route({ agent: "worker", skills: ["focused"] }).model, "openai-codex/test-model:high");
	const read = { path: "/skills/focused/SKILL.md", directSkill: "focused" };
	assert.deepEqual(route({ ...read }, "openai-codex", { toolName: "read" }), read);
	assert.equal(route({ directSkill: "focused" }).model, "openai-codex/skill-model:low");
});

test("unknown explicit routes and unavailable models block child launch", () => {
	assert.throws(() => route({ command: "unknown-command" }), /unknown|not found/i);
	assert.throws(() => route({ directSkill: "unknown-skill" }), /unknown|not found/i);
	assert.throws(() => route({ command: "missing" }), /unavailable|not found|not available/i);
	assert.throws(() => route({ command: "foreign" }), /provider|route/i);
});

test("explicit model selection cannot silently change the inference provider", () => {
	assert.throws(() => route({ agent: "worker", model: "anthropic/claude-sonnet-5" }), /provider/i);
});

test("workflow command routes reach native launches without routing-only fields", async () => {
	const { calls } = await execute(`
return await runs.all([
  {key: 'command', agent: 'worker', command: 'review', task: 'review'},
  {key: 'skill', agent: 'worker', directSkill: 'focused', task: 'focus'}
]);
`);
	assert.equal(calls[0].model, "openai-codex/command-model:medium");
	assert.equal(calls[1].model, "openai-codex/skill-model:low");
	assert.ok(calls.every((call) => !("command" in call) && !("directSkill" in call)));
});

test("an invalid route stops a workflow before any child launches", async () => {
	const { calls, result } = await execute(`
try {
  await runs.all([
    {key: 'valid', agent: 'worker', task: 'valid'},
    {key: 'invalid', agent: 'worker', command: 'missing', task: 'invalid'}
  ]);
  return 'launched';
} catch (error) {
  return error.message;
}
`);
	assert.deepEqual(calls, []);
	assert.match(result.value, /unavailable/i);
});
