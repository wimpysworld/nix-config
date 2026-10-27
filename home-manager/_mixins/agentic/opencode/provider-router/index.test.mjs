// Gate: the OpenCode launcher build runs this suite in postCheck.
import assert from "node:assert/strict";
import { test } from "bun:test";
import createRouter from "./index.mjs";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const routes = { garfield: { openai: "gpt-6.1-terra", anthropic: "claude-haiku-5-5" } };
const key = "nix-config.opencode-provider-router.v2/child";
function task(provider = "openai", child = "child", id = "task-1") {
  return { type: "assistant", model: { providerID: provider, id: "parent-model" }, content: [{
    type: "tool", name: "subagent", id,
    state: { status: "running", input: { agent: "garfield" }, metadata: { sessionID: child } },
  }] };
}
async function fixture(provider = "openai", map = routes, variants = {}) {
  const state = {
    sessions: { root: { id: "root", model: { providerID: "google", id: "orchestrator-model" } }, child: { id: "child", parentID: "root", agent: "garfield",
      model: { providerID: provider, id: "native-model", variant: "high" },
      permissions: [{ action: "subagent", resource: "*", effect: "deny" }] } },
    messages: { root: [task(provider)], child: [] },
    models: Object.entries(routes.garfield).map(([providerID, id]) => ({ providerID, id,
      variants: [{ id: "high" }, { id: "max" }] })), storage: {}, notices: [],
  };
  let prompt;
  const ctx = {
    location: { directory: "/project" },
    session: {
      hook: async (name, callback) => { assert.equal(name, "prompt"); prompt = callback; },
      get: async ({ sessionID }) => structuredClone(state.sessions[sessionID]),
      context: async ({ sessionID }) => structuredClone(state.messages[sessionID]),
      switchModel: async ({ sessionID, model }) => { state.sessions[sessionID].model = model; },
      synthetic: async (input) => { state.notices.push(input); },
    },
    model: { list: async () => state.models },
    storage: {
      get: async (key) => structuredClone(state.storage[key]),
      set: async (key, value) => { state.storage[key] = structuredClone(value); },
    },
  };
  const install = async (map = routes, variants = {}) => createRouter(ctx, map, variants);
  await install(map, variants);
  const send = async (sessionID = "child") => {
    const event = { sessionID, messageID: "user", prompt: { text: "Do the task." }, metadata: { existing: true } };
    await prompt(event);
    await new Promise((resolve) => setTimeout(resolve, 0));
    return event;
  };
  const resume = (provider = "anthropic") => {
    state.messages.root[0].content[0].state.status = "completed";
    state.messages.root.push(task(provider, "child", "task-2"));
  };
  return { state, ctx, install, send, resume };
}
const parentModel = { providerID: "google", id: "orchestrator-model" };
// The prompt hook never rejects. It logs the error, and an invalid route runs
// the child on the parent model with one notice in the parent session.
async function failsOpen(f, pattern, { sends = () => f.send(), model = parentModel } = {}) {
  const before = model ?? structuredClone(f.state.sessions.child.model);
  const notices = f.state.notices.length;
  const errors = [];
  const original = console.error;
  console.error = (...args) => { errors.push(args); };
  try {
    await sends();
  } finally {
    console.error = original;
  }
  assert.equal(errors.length, 1);
  assert.match(errors[0][0], /^Provider Router: /);
  assert.match(String(errors[0][1]?.message), pattern);
  assert.deepEqual(f.state.sessions.child.model, before);
  assert.equal(f.state.notices.length, notices + 1);
  const notice = f.state.notices.at(-1);
  assert.equal(notice.sessionID, "root");
  assert.equal(notice.description, "Provider Router");
  assert.equal(notice.resume, false);
  assert.match(notice.text, /^Provider Router: .*garfield.* so garfield ran on /);
  assert.doesNotMatch(notice.text, /[\u2013\u2014]/);
  return notice;
}
for (const [provider, id] of Object.entries(routes.garfield)) {
  test(`routes ${provider} and preserves worker permissions and prompt`, async () => {
    const f = await fixture(provider);
    const permissions = structuredClone(f.state.sessions.child.permissions);
    const event = await f.send();
    assert.deepEqual(f.state.notices, []);
    assert.deepEqual(f.state.sessions.child.model, { providerID: provider, id, variant: "high" });
    assert.deepEqual(f.state.sessions.child.permissions, permissions);
    assert.equal(event.prompt.text, "Do the task.");
    assert.equal(event.metadata.existing, true);
  });
}
test("missing routes, root sessions, nested sessions and native history remain native", async () => {
  for (const change of [
    (f) => { f.state.messages.root[0].model.providerID = "google"; },
    (f) => { f.state.messages.root[0].content[0].state.input.agent = "donatello"; },
    (f) => { f.state.sessions.child.parentID = undefined; },
    (f) => { f.state.sessions.root.parentID = "grandparent"; },
    (f) => { f.state.messages.child.push({ type: "user", text: "Migrated native history" }); },
    (f) => { f.state.messages.child.push({ type: "compaction" }); },
    (f) => { f.state.messages.root.push(task("anthropic", "child", "task-2")); },
    (f) => { f.state.messages.root = []; },
    (f) => { f.state.messages.root[0].content[0].state.input.model = "openai/user-override"; },
  ]) {
    const f = await fixture(); change(f);
    const before = structuredClone(f.state.sessions.child.model);
    await f.send();
    assert.deepEqual(f.state.sessions.child.model, before);
    assert.deepEqual(f.state.storage, {});
    assert.deepEqual(f.state.notices, []);
  }
});
test("exact model and variant failures run on the parent model", async () => {
  for (const id of ["missing", "other/model", "", 42]) {
    const f = await fixture("openai", { garfield: { openai: id } });
    await failsOpen(f, /exact model/);
  }
  for (const variant of ["missing", "Bad Variant", 42]) {
    const f = await fixture("anthropic", routes, { garfield: { anthropic: variant } });
    await failsOpen(f, /variant/);
  }
  const f = await fixture();
  f.state.models[0].providerID = "other-provider";
  const notice = await failsOpen(f, /unavailable exact model/);
  assert.equal(notice.text, "Provider Router: the route for garfield (openai/gpt-6.1-terra variant high) is not available, " +
    "so garfield ran on google/orchestrator-model.");
});
test("one invalid invocation posts one notice across retries", async () => {
  const f = await fixture("openai", { garfield: { openai: "missing" } });
  await failsOpen(f, /exact model/);
  f.state.sessions.child.model = { providerID: "openai", id: "native-model" };
  const original = console.error;
  console.error = () => {};
  try { await f.send(); } finally { console.error = original; }
  assert.deepEqual(f.state.sessions.child.model, parentModel);
  assert.equal(f.state.notices.length, 1);
});
test("a missing parent model keeps the native model", async () => {
  const f = await fixture("openai", { garfield: { openai: "missing" } });
  delete f.state.sessions.root.model;
  delete f.state.messages.root[0].model.id;
  const notice = await failsOpen(f, /exact model/, { model: null });
  assert.match(notice.text, /so garfield ran on its native model openai\/native-model variant high\./);
});
test("the parent model falls back to the latest parent assistant message", async () => {
  const f = await fixture("openai", { garfield: { openai: "missing" } });
  delete f.state.sessions.root.model;
  await failsOpen(f, /exact model/, { model: { providerID: "openai", id: "parent-model" } });
});
test("a failing notice does not reject the prompt", async () => {
  const f = await fixture("openai", { garfield: { openai: "missing" } });
  const errors = [];
  const original = console.error;
  console.error = (...args) => { errors.push(args); };
  f.ctx.session.synthetic = async () => { throw new Error("notice unavailable"); };
  try {
    await f.send();
  } finally {
    console.error = original;
  }
  assert.deepEqual(f.state.sessions.child.model, parentModel);
  assert.deepEqual(errors.map((args) => args[0]),
    ["Provider Router: prompt hook failed.", "Provider Router: notice failed."]);
});
test("legacy { data } client results still route", async () => {
  const f = await fixture();
  const { context, get } = f.ctx.session;
  f.ctx.session.get = async (args) => ({ data: await get(args) });
  f.ctx.session.context = async (args) => ({ data: await context(args) });
  f.ctx.model.list = async () => ({ data: f.state.models });
  await f.send();
  assert.deepEqual(f.state.sessions.child.model, { providerID: "openai", id: "gpt-6.1-terra", variant: "high" });
});
test("failed or odd session context resolves the prompt unchanged", async () => {
  for (const context of [
    async () => { throw new Error("context unavailable"); },
    async () => undefined,
    async () => ({ messages: [] }),
  ]) {
    const f = await fixture();
    f.ctx.session.context = context;
    const notice = await failsOpen(f, /context/, { model: null });
    assert.match(notice.text, /internal error, so garfield ran on its native model openai\/native-model variant high\./);
    assert.deepEqual(f.state.storage, {});
  }
});
test("siblings follow the originating assistant independently", async () => {
  const f = await fixture();
  f.state.sessions.sibling = { ...f.state.sessions.child, id: "sibling" };
  f.state.messages.sibling = [];
  f.state.messages.root.push(task("anthropic", "sibling", "task-2"));
  await Promise.all([f.send(), f.send("sibling")]);
  assert.equal(f.state.sessions.child.model.providerID, "openai");
  assert.equal(f.state.sessions.sibling.model.providerID, "anthropic");
});
test("durable route survives restart, compaction and parent provider changes", async () => {
  const f = await fixture("anthropic", routes, { garfield: { anthropic: "max" } });
  await f.send(); f.resume("openai");
  f.state.storage = JSON.parse(JSON.stringify(f.state.storage));
  f.state.messages.child = [{ type: "compaction" }];
  f.state.messages.root.shift();
  await f.install({});
  await f.send();
  assert.deepEqual(f.state.sessions.child.model, { providerID: "anthropic", id: "claude-haiku-5-5", variant: "max" });
});
test("same-child overlap and repeated invocation fail before prompt admission", async () => {
  const f = await fixture();
  const errors = [];
  const original = console.error;
  console.error = (...args) => { errors.push(args); };
  try {
    const results = await Promise.allSettled([f.send(), f.send()]);
    assert.equal(results.filter((r) => r.status === "rejected").length, 0);
  } finally {
    console.error = original;
  }
  assert.equal(errors.length, 1);
  assert.match(errors[0][1].message, /concurrent child/);
  assert.equal(f.state.notices.length, 1);
  await f.install();
  const saved = structuredClone(f.state.storage);
  await failsOpen(f, /concurrent child/);
  assert.deepEqual(f.state.storage, saved);
});
test("fenced permission evaluation changes ask only and preserves explicit denies", async () => {
  const root = mkdtempSync(join(tmpdir(), "opencode-router-plugin-"));
  const map = join(root, "routes.json");
  writeFileSync(map, "{}");
  const path = join(root, "index.ts");
  writeFileSync(path, readFileSync(new URL("../plugins/provider-router.ts", import.meta.url), "utf8")
    .replaceAll("@routerModule@", new URL("./index.mjs", import.meta.url).href)
    .replaceAll("@routerMap@", map).replaceAll("@routerVariants@", map));
  const { default: plugin } = await import(path);
  const original = process.env.FENCE_SANDBOX;
  try {
    for (const fenced of ["0", "1"]) {
      process.env.FENCE_SANDBOX = fenced;
      let evaluate;
      await plugin.setup({
        session: { hook: async () => {} },
        permission: { hook: async (name, callback) => { assert.equal(name, "evaluate"); evaluate = callback; } },
      });
      assert.equal(typeof evaluate, fenced === "1" ? "function" : "undefined");
      if (!evaluate) continue;
      for (const action of ["external_directory", "webfetch", "websearch", "slack_slack_post", "subagent"]) {
        for (const effect of ["ask", "deny", "allow"]) {
          const event = { action, effect, resources: ["*"] };
          await evaluate(event);
          assert.deepEqual(event, { action, effect: effect === "ask" ? "allow" : effect, resources: ["*"] });
        }
      }
    }
  } finally {
    if (original === undefined) delete process.env.FENCE_SANDBOX;
    else process.env.FENCE_SANDBOX = original;
  }
});

test("invalid saved state, ambiguous resume and unavailable saved routes run on the parent model", async () => {
  for (const value of [null, false, 0, "", [], "invalid", { parentID: "wrong" }]) {
    const f = await fixture(); f.state.storage[key] = value;
    await failsOpen(f, /invalid saved route/);
  }
  const f = await fixture(); await f.send(); f.resume();
  f.state.models = [];
  await failsOpen(f, /unavailable exact model/);
  f.state.messages.root.push(task("openai", "child", "third"));
  await failsOpen(f, /ambiguous/);
});

// OpenCode 2.1.4 runs the child prompt hook before it publishes the child
// session ID to the running subagent part.
function launch(f, input = {}, provider = "openai", id = "task-1") {
  const part = task(provider, "child", id);
  part.content[0].state.metadata = {};
  Object.assign(part.content[0].state.input, { description: "Fix it", prompt: "Do the task." }, input);
  f.state.messages.root.push(part);
}
async function unpublished(provider = "openai") {
  const f = await fixture(provider);
  f.state.messages.root = [];
  f.state.sessions.child.title = "Fix it";
  return f;
}
test("an unpublished launch routes when one candidate matches", async () => {
  for (const setup of [
    (f) => launch(f),
    (f) => { launch(f); launch(f, { description: "Other" }, "anthropic", "task-2"); },
    (f) => { launch(f); launch(f, { prompt: "Other work." }, "anthropic", "task-2"); },
    (f) => { launch(f); launch(f, { agent: "donatello" }, "anthropic", "task-2"); },
  ]) {
    const f = await unpublished(); setup(f);
    await f.send();
    assert.deepEqual(f.state.notices, []);
    assert.deepEqual(f.state.sessions.child.model, { providerID: "openai", id: "gpt-6.1-terra", variant: "high" });
    assert.equal(f.state.storage[key].taskID, "task-1");
  }
  const f = await fixture("anthropic", routes, { garfield: { anthropic: "max" } });
  await f.send(); f.resume("openai");
  launch(f, { sessionID: "child", description: "Resumed" }, "openai", "task-3");
  f.state.messages.root.splice(1, 1);
  f.state.sessions.child.model = { providerID: "openai", id: "native-model" };
  await f.send();
  assert.deepEqual(f.state.sessions.child.model, { providerID: "anthropic", id: "claude-haiku-5-5", variant: "max" });
});
test("several unpublished launches run on the parent model with one notice", async () => {
  const f = await unpublished();
  launch(f); launch(f, {}, "anthropic", "task-2");
  const notice = await failsOpen(f, /ambiguous concurrent subagent launches/);
  assert.equal(notice.text, "Provider Router: routing for garfield is ambiguous: several subagent launches " +
    "are running at once, so garfield ran on google/orchestrator-model.");
  assert.deepEqual(f.state.storage, {});
});
test("a native default variant routes without a variant", async () => {
  const f = await unpublished();
  f.state.sessions.child.model.variant = "default";
  launch(f);
  await f.send();
  assert.deepEqual(f.state.notices, []);
  assert.deepEqual(f.state.sessions.child.model, { providerID: "openai", id: "gpt-6.1-terra" });
});
test("a published session ID wins over unpublished launches", async () => {
  const f = await fixture();
  launch(f, {}, "anthropic", "task-2");
  await f.send();
  assert.deepEqual(f.state.notices, []);
  assert.deepEqual(f.state.sessions.child.model, { providerID: "openai", id: "gpt-6.1-terra", variant: "high" });
});
test("prompts without a matching subagent launch stay native", async () => {
  for (const setup of [
    () => {},
    (f) => launch(f, { description: "Other" }),
    (f) => launch(f, { prompt: "Other work." }),
    (f) => launch(f, { sessionID: "other" }),
    (f) => { launch(f, { agent: "donatello" }); launch(f, { agent: "donatello" }, "anthropic", "task-2"); },
  ]) {
    const f = await unpublished(); setup(f);
    const before = structuredClone(f.state.sessions.child.model);
    await f.send();
    assert.deepEqual(f.state.sessions.child.model, before);
    assert.deepEqual(f.state.storage, {});
    assert.deepEqual(f.state.notices, []);
  }
});
