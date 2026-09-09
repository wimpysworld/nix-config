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
const originalHome = process.env.HOME;
let registerProviderRouter;
try {
	process.env.HOME = fixtureHome;
	({ default: registerProviderRouter } = await import("./index.ts"));
} finally {
	if (originalHome === undefined) delete process.env.HOME;
	else process.env.HOME = originalHome;
}

function route(input, provider = "openai-codex") {
	const handlers = new Map();
	registerProviderRouter({ on: (name, handler) => handlers.set(name, handler) });
	handlers.get("tool_call")({ toolName: "subagent", input }, {
		model: { provider, id: "parent-model" },
		modelRegistry: { find: (name, id) => name === "openai-codex" && id === "test-model" },
	});
	return input;
}

function childResult(key, params = {}) {
	return { key, runId: `test-${key}`, ok: true, output: params.task ?? key, artifactPaths: [] };
}

async function execute(script) {
	const input = route({ workflowScript: script });
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

test("overrides a mapped model but preserves unknown agents", async () => {
	const { calls } = await execute(`
return await runs.all([
  {key: 'known', agent: 'worker', task: 'known', model: 'other/model'},
  {key: 'unknown', agent: 'unmapped', task: 'unknown', model: 'other/model'}
]);
`);
	assert.equal(calls[0].model, "openai-codex/test-model:high");
	assert.equal(calls[1].model, "other/model");
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

test("keeps scripts unchanged when the provider has no route", () => {
	const workflowScript = "return 42;";
	assert.equal(route({ workflowScript }, "unknown").workflowScript, workflowScript);
});

test("keeps management calls unchanged and routes direct children", () => {
	const validation = { action: "validate", workflowScript: "return 42;" };
	assert.deepEqual(route({ ...validation }), validation);
	assert.equal(route({ agent: "worker", task: "direct" }).model, "openai-codex/test-model:high");
});
