// Gate: the OpenCode launcher build runs this suite in postCheck.
import assert from "node:assert/strict";
import { test } from "bun:test";
import createRouter from "./index.mjs";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const routes = { garfield: { openai: "gpt-5.6-terra", anthropic: "claude-haiku-5-5" } };
const key = "nix-config.opencode-provider-router.v2/child";
function task(provider = "openai", child = "child", id = "task-1") {
  return { type: "assistant", model: { providerID: provider, id: "parent-model" }, content: [{
    type: "tool", name: "subagent", id,
    state: { status: "running", input: { agent: "garfield" }, metadata: { sessionID: child } },
  }] };
}
async function fixture(provider = "openai", map = routes, variants = {}) {
  const state = {
    sessions: { root: { id: "root" }, child: { id: "child", parentID: "root", agent: "garfield",
      model: { providerID: provider, id: "native-model", variant: "high" },
      permissions: [{ action: "subagent", resource: "*", effect: "deny" }] } },
    messages: { root: [task(provider)], child: [] },
    models: Object.entries(routes.garfield).map(([providerID, id]) => ({ providerID, id,
      variants: [{ id: "high" }, { id: "max" }] })), storage: {},
  };
  let prompt;
  const ctx = {
    location: { directory: "/project" },
    session: {
      hook: async (name, callback) => { assert.equal(name, "prompt"); prompt = callback; },
      get: async ({ sessionID }) => structuredClone(state.sessions[sessionID]),
      context: async ({ sessionID }) => ({ data: structuredClone(state.messages[sessionID]) }),
      switchModel: async ({ sessionID, model }) => { state.sessions[sessionID].model = model; },
    },
    model: { list: async () => ({ data: state.models }) },
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
    return event;
  };
  const resume = (provider = "anthropic") => {
    state.messages.root[0].content[0].state.status = "completed";
    state.messages.root.push(task(provider, "child", "task-2"));
  };
  return { state, ctx, install, send, resume };
}
for (const [provider, id] of Object.entries(routes.garfield)) {
  test(`routes ${provider} and preserves worker permissions and prompt`, async () => {
    const f = await fixture(provider);
    const permissions = structuredClone(f.state.sessions.child.permissions);
    const event = await f.send();
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
  }
});
test("exact model and variant failures never fall back", async () => {
  for (const id of ["missing", "other/model", "", 42]) {
    const f = await fixture("openai", { garfield: { openai: id } });
    await assert.rejects(f.send(), /exact model/);
    assert.equal(f.state.sessions.child.model.id, "native-model");
  }
  for (const variant of ["missing", "Bad Variant", 42]) {
    const f = await fixture("anthropic", routes, { garfield: { anthropic: variant } });
    await assert.rejects(f.send(), /variant/);
  }
  const f = await fixture();
  f.state.models[0].providerID = "other-provider";
  await assert.rejects(f.send(), /unavailable exact model/);
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
  const results = await Promise.allSettled([f.send(), f.send()]);
  assert.equal(results.filter((r) => r.status === "rejected").length, 1);
  await f.install();
  await assert.rejects(f.send(), /concurrent child/);
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

test("invalid saved state, ambiguous resume and unavailable saved routes reject", async () => {
  for (const value of [null, false, 0, "", [], "invalid", { parentID: "wrong" }]) {
    const f = await fixture(); f.state.storage[key] = value;
    await assert.rejects(f.send(), /invalid saved route/);
  }
  const f = await fixture(); await f.send(); f.resume();
  f.state.models = [];
  await assert.rejects(f.send(), /unavailable exact model/);
  f.state.messages.root.push(task("openai", "child", "third"));
  await assert.rejects(f.send(), /ambiguous/);
});
