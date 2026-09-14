import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { test } from "node:test";
import createRouter from "./index.mjs";

const routes = {
  garfield: { openai: "gpt-5.6-terra", anthropic: "claude-sonnet-5" },
};

function task(provider = "openai", child = "child", id = "task-1") {
  return {
    info: { role: "assistant", providerID: provider, modelID: "parent-model" },
    parts: [
      {
        id,
        type: "tool",
        tool: "task",
        state: {
          status: "running",
          input: { subagent_type: "garfield" },
          metadata: { sessionId: child },
        },
      },
    ],
  };
}

function draft(sessionID = "child", providerID = "openai", agent = "garfield") {
  return {
    message: {
      id: `user-${sessionID}`,
      role: "user",
      sessionID,
      agent,
      model: { providerID, modelID: "native-model", variant: "high" },
      tools: { task: false },
    },
    parts: [
      {
        id: "text-1",
        type: "text",
        text: "Do the task.",
        metadata: { existing: true },
      },
    ],
  };
}

function fixture(provider = "openai", map = routes) {
  const state = {
    sessions: {
      root: {
        id: "root",
        permission: [{ permission: "task", action: "deny" }],
      },
      child: { id: "child", parentID: "root" },
    },
    messages: { root: [task(provider)], child: [] },
    catalogue: {
      connected: ["openai", "anthropic"],
      all: Object.entries(routes.garfield).map(([id, model]) => ({
        id,
        models: { [model]: { id: model } },
      })),
    },
  };
  const reads = [];
  const client = {
    session: {
      get: async ({ path: { id } }) => {
        reads.push(["get", id]);
        return { data: state.sessions[id] };
      },
      messages: async ({ path: { id } }) => {
        reads.push(["messages", id]);
        return { data: state.messages[id] };
      },
    },
    provider: {
      list: async () => {
        reads.push(["providers"]);
        return { data: state.catalogue };
      },
    },
  };
  return { state, client, reads, hooks: createRouter(client, map) };
}

async function send(f, output = draft(), hooks = f.hooks) {
  await hooks["chat.message"]({ sessionID: output.message.sessionID }, output);
  return output;
}

function persist(f, output) {
  f.state.messages.child.push(
    JSON.parse(JSON.stringify({ info: output.message, parts: output.parts })),
  );
}

function resume(f, provider = "anthropic") {
  f.state.messages.root[0].parts[0].state.status = "completed";
  f.state.messages.root.push(task(provider, "child", "task-2"));
}

for (const [provider, modelID] of Object.entries(routes.garfield)) {
  test(`new ${provider} route mutates the live model, not task permissions`, async () => {
    const f = fixture(provider);
    const output = draft("child", provider);
    const model = output.message.model;
    const parent = structuredClone(f.state);
    const result = await send(f, output);
    assert.equal(result.message.model, model);
    assert.equal(model.modelID, modelID);
    assert.equal(model.providerID, provider);
    assert.equal(model.variant, "high");
    assert.deepEqual(result.message.tools, { task: false });
    assert.equal(result.parts[0].text, "Do the task.");
    assert.equal(result.parts[0].metadata.existing, true);
    assert.deepEqual(f.state, parent);
    assert.deepEqual(Object.keys(f.hooks).sort(), ["chat.message", "event"]);
  });
}

for (const [name, provider, agent] of [
  ["Google", "google", "garfield"],
  ["unmapped agent", "openai", "donatello"],
]) {
  test(`${name} retains native behaviour`, async () => {
    const f = fixture(provider);
    f.state.messages.root[0].parts[0].state.input.subagent_type = agent;
    const output = draft("child", provider, agent);
    const before = structuredClone(output);
    assert.deepEqual(await send(f, output), before);
    assert.ok(!f.reads.some(([kind]) => kind === "providers"));
  });
}

test("invalid exact model, qualified model, and disconnected provider reject without fallback", async () => {
  for (const model of ["missing", "anthropic/claude-sonnet-5", "", 42]) {
    const f = fixture("openai", { garfield: { openai: model } });
    const output = draft();
    await assert.rejects(send(f, output), /exact model/);
    assert.equal(output.message.model.modelID, "native-model");
  }
  const f = fixture();
  f.state.catalogue.connected = ["anthropic"];
  await assert.rejects(send(f), /unavailable exact model openai/);
});

test("new child follows its containing assistant, not the latest parent message", async () => {
  const f = fixture("anthropic");
  f.state.messages.root.push(task("openai", "sibling", "task-2"));
  const result = await send(f);
  assert.equal(result.message.model.providerID, "anthropic");
  assert.equal(result.message.model.modelID, "claude-sonnet-5");
});

test("root and nested sessions remain unchanged, including concurrent root hooks", async () => {
  const f = fixture();
  const root = draft("root");
  const before = structuredClone(root);
  await Promise.all([send(f, root), send(f, draft("root"))]);
  assert.deepEqual(root, before);
  f.state.sessions.child.parentID = "nested-parent";
  f.state.sessions["nested-parent"] = { id: "nested-parent", parentID: "root" };
  assert.deepEqual(await send(f), draft());
});

test("simultaneous siblings correlate independently", async () => {
  const f = fixture();
  f.state.sessions.sibling = { id: "sibling", parentID: "root" };
  f.state.messages.sibling = [];
  f.state.messages.root.push(task("anthropic", "sibling", "task-2"));
  const [first, second] = await Promise.all([
    send(f),
    send(f, draft("sibling")),
  ]);
  assert.equal(first.message.model.modelID, "gpt-5.6-terra");
  assert.equal(second.message.model.modelID, "claude-sonnet-5");
});

test("ambiguous, missing, or wrong-agent task correlation retains native behaviour", async () => {
  for (const change of [
    (f) => f.state.messages.root.push(task("anthropic", "child", "task-2")),
    (f) => {
      f.state.messages.root = [];
    },
    (f) => {
      f.state.messages.root[0].parts[0].state.input.subagent_type = "donatello";
    },
  ]) {
    const f = fixture();
    change(f);
    assert.deepEqual(await send(f), draft());
  }
});

test("resume restores the saved model after the parent provider changes", async () => {
  const f = fixture();
  persist(f, await send(f));
  resume(f);
  const result = await send(f, draft("child", "anthropic"));
  assert.equal(result.message.model.providerID, "openai");
  assert.equal(result.message.model.modelID, "gpt-5.6-terra");
});

test("serialised history restores the route in a fresh process", async () => {
  const f = fixture();
  persist(f, await send(f));
  resume(f);
  const script = `
    import createRouter from ${JSON.stringify(new URL("./index.mjs", import.meta.url).href)};
    const state = ${JSON.stringify(f.state)};
    const client = {
      session: {
        get: async ({path:{id}}) => ({data:state.sessions[id]}),
        messages: async ({path:{id}}) => ({data:state.messages[id]}),
      },
      provider: {list:async () => ({data:state.catalogue})},
    };
    const output = ${JSON.stringify(draft("child", "anthropic"))};
    await createRouter(client, {})["chat.message"]({sessionID:"child"}, output);
    process.stdout.write(JSON.stringify(output.message.model));
  `;
  const model = JSON.parse(
    execFileSync(process.execPath, ["--input-type=module", "-e", script], {
      encoding: "utf8",
    }),
  );
  assert.equal(model.providerID, "openai");
  assert.equal(model.modelID, "gpt-5.6-terra");
});

test("same-child overlap rejects during lookup and before persistence", async () => {
  const f = fixture();
  const results = await Promise.allSettled([send(f), send(f)]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.filter((r) => r.status === "rejected").length, 1);
  await assert.rejects(send(f), /concurrent child prompts/);
});

test("saved history excludes an active same-child prompt after restart", async () => {
  const f = fixture();
  persist(f, await send(f));
  await assert.rejects(
    send(f, draft(), createRouter(f.client, routes)),
    /concurrent child prompts/,
  );
});

test("native history is not retroactively routed", async () => {
  const f = fixture();
  persist(f, draft());
  assert.deepEqual(await send(f), draft());
});

test("saved route corruption and unavailable saved model reject", async () => {
  const f = fixture();
  persist(f, await send(f));
  resume(f);
  f.state.catalogue.all[0].models = {};
  await assert.rejects(send(f), /unavailable exact model/);
  f.state.messages.child[0].info.model.modelID = "tampered";
  await assert.rejects(send(f), /invalid saved route/);
});

test("invalid saved marker types reject", async () => {
  for (const marker of [null, false, 0, "", [], "invalid"]) {
    const f = fixture();
    persist(f, await send(f));
    resume(f);
    f.state.messages.child[0].parts[0].metadata[
      "nix-config.opencode-provider-router.v1"
    ] = marker;
    await assert.rejects(send(f), /invalid saved route/);
  }
});

test("the session model does not select the route", async () => {
  const f = fixture("anthropic");
  f.state.sessions.child.model = { providerID: "google", id: "native-model" };
  assert.equal((await send(f)).message.model.providerID, "anthropic");
});

test("an unavailable provider cannot use the same model from another provider", async () => {
  const f = fixture();
  f.state.catalogue.all[0].id = "other-provider";
  await assert.rejects(send(f), /unavailable exact model openai/);
});

test("the generated Home Manager plugin loads its map", {
  skip: !process.env.OPENCODE_ROUTER_PLUGIN,
}, async () => {
  const { default: plugin } = await import(process.env.OPENCODE_ROUTER_PLUGIN);
  const f = fixture();
  const hooks = await plugin({ client: f.client });
  assert.equal(
    (await send(f, draft(), hooks)).message.model.modelID,
    "gpt-5.6-terra",
  );
});

test("task completion releases the in-process guard without changing the event", async () => {
  const f = fixture();
  persist(f, await send(f));
  resume(f);
  const event = {
    type: "message.part.updated",
    properties: { part: f.state.messages.root[0].parts[0] },
  };
  const before = structuredClone(event);
  await f.hooks.event({ event });
  assert.deepEqual(event, before);
  assert.equal((await send(f)).message.model.modelID, "gpt-5.6-terra");
});
