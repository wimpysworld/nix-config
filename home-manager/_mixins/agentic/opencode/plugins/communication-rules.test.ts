// Gate: the OpenCode launcher build runs this suite in postCheck.
import { test } from "bun:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

async function fixture() {
  const root = mkdtempSync(join(tmpdir(), "opencode-tripwire-test-"));
  const decision = join(root, "decision.json");
  const payload = join(root, "payload.json");
  const scanner = join(root, "scanner");
  const rules = join(root, "rules");
  const correction = join(root, "correction");
  writeFileSync(rules, "Base rules"); writeFileSync(correction, "Correct the prose.");
  const python = Bun.which("python3");
  assert.ok(python, "The package test gate must supply Python.");
  writeFileSync(scanner, `#!${python}
import json, sys
if sys.argv[1] == "remind-brief":
    print("Rules reminder")
else:
    with open(${JSON.stringify(payload)}, "w") as f: f.write(sys.stdin.read())
    with open(${JSON.stringify(decision)}) as f: result = json.load(f)
    print(json.dumps(result))
    if sys.argv[2] == "context":
        with open(${JSON.stringify(decision)}, "w") as f:
            json.dump({**result, "inject_base_rules": False, "append_correction": False}, f)
`, { mode: 0o755 });
  const setDecision = (value: unknown) => writeFileSync(decision, JSON.stringify(value));
  setDecision({ decision: "pass" });
  const pluginPath = join(root, "plugin.ts");
  writeFileSync(pluginPath, readFileSync(new URL("./communication-rules.ts", import.meta.url), "utf8")
    .replaceAll("@tripwireScanner@", scanner).replaceAll("@tripwireRules@", rules)
    .replaceAll("@tripwireCorrectionPrompt@", correction));
  const { default: plugin } = await import(pluginPath);
  const hooks: Record<string, Function> = {};
  const notices: any[] = [];
  let streamController: ReadableStreamDefaultController;
  let streamClosed = false;
  let notified: () => void = () => {};
  const notice = new Promise<void>((resolve) => { notified = resolve; });
  const stream = new ReadableStream({
    start(controller) { streamController = controller; },
    cancel() { streamClosed = true; },
  });
  const ctx = {
    location: { directory: "/project" },
    session: {
      hook: async (name: string, callback: Function) => { hooks[name] = callback; },
      synthetic: async (input: unknown) => { notices.push(input); notified(); },
      get: async ({ sessionID }: any) => ({ id: sessionID, location: { directory: "/project" } }),
      // V2 plugin client methods resolve to the bare value, not `{ data }`.
      context: async () => [{ id: "answer", type: "assistant", content: [{ type: "text", text: "Bad prose." }] }],
    },
    tool: {
      hook: async (name: string, callback: Function) => { hooks[name] = callback; },
      list: async () => [{ id: "linear_save_comment", name: "save_comment", options: { namespace: "linear" } }],
    },
    event: { subscribe: ({ signal }: any) => {
      signal.addEventListener("abort", () => {
        if (!streamClosed) streamController.close();
      }, { once: true });
      return stream;
    } },
  };
  const cleanup = await plugin.setup(ctx);
  return { hooks, notices, notice, cleanup, setDecision, ctx,
    close: () => { streamClosed = true; streamController.close(); },
    fail: (error: unknown) => { streamClosed = true; streamController.error(error); },
    send: (event: unknown) => streamController.enqueue(event),
    payload: () => JSON.parse(readFileSync(payload, "utf8")),
    corrupt: () => writeFileSync(decision, "not JSON"),
  };
}
test("V2 context injects structured rules and pending correction", async () => {
  const f = await fixture();
  f.setDecision({ decision: "pass", inject_base_rules: true, append_correction: true });
  const event = { sessionID: "session", system: [] };
  await f.hooks.context(event); await f.hooks.context(event);
  assert.deepEqual(event.system, [{ type: "text", text: "Rules reminder" }, { type: "text", text: "Correct the prose." }]);
  await f.cleanup();
});
for (const hook of ["compaction", "generate", "title"]) {
  test(`V2 ${hook} injects rules without consuming the primary correction`, async () => {
    const f = await fixture();
    try {
      f.setDecision({ decision: "pass", inject_base_rules: true, append_correction: true });
      const auxiliary = { sessionID: "session", system: [] };
      await f.hooks[hook](auxiliary); await f.hooks[hook](auxiliary);
      assert.deepEqual(auxiliary.system, [{ type: "text", text: "Rules reminder" }]);
      const primary = { sessionID: "session", system: [] };
      await f.hooks.context(primary);
      assert.deepEqual(primary.system, [{ type: "text", text: "Rules reminder" }, { type: "text", text: "Correct the prose." }]);
      const next = { sessionID: "session", system: [] };
      await f.hooks.context(next);
      assert.deepEqual(next.system, []);
    } finally {
      await f.cleanup();
    }
  });
}
test("V2 writes, shell commands and namespaced posts reach the policy core", async () => {
  const f = await fixture();
  for (const [tool, input, expected] of [
    ["write", { path: "/tmp/a", content: "Text" }, "write"],
    ["edit", { path: "/tmp/a", newString: "Text" }, "edit"],
    ["patch", { patch: "+++ file\n+Text" }, "patch"],
    ["shell", { command: "printf Text > /tmp/a" }, "shell"],
    ["linear_save_comment", { body: "Text" }, "mcp__linear__save_comment"],
  ]) {
    await f.hooks["execute.before"]({ tool, input, sessionID: "session" });
    assert.deepEqual(f.payload(), { event: "tool.execute.before", tool: expected, sessionID: "session", args: input });
  }
  await f.cleanup();
});
test("policy blocks, unknown decisions and scanner errors fail closed", async () => {
  const f = await fixture();
  const event = { tool: "write", input: { path: "/tmp/a", content: "Text" }, sessionID: "session" };
  for (const decision of [{ decision: "block", notice: "Revise." }, { decision: "unknown" }]) {
    f.setDecision(decision);
    await assert.rejects(f.hooks["execute.before"](event));
  }
  f.corrupt(); await assert.rejects(f.hooks["execute.before"](event));
  for (const decision of ["yield", "allow-revise"]) {
    f.setDecision({ decision, notice: "Notice" });
    await f.hooks["execute.before"](event);
  }
  assert.equal(f.notices.length, 2);
  assert.ok(f.notices.every((item) => item.resume === false));
  await f.cleanup();
});
test("completed V2 prose is observed after display and queues a correction notice", async () => {
  const f = await fixture();
  f.setDecision({ decision: "block", notice: "Revise the answer." });
  f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "answer", finish: "stop" } });
  await f.notice;
  assert.equal(f.payload().message.content, "Bad prose.");
  assert.equal(f.notices[0].text, "Revise the answer.");
  assert.equal(f.notices[0].resume, false);
  f.setDecision({ decision: "pass", append_correction: true });
  const context = { sessionID: "session", system: [] };
  await f.hooks.context(context);
  assert.deepEqual(context.system, [{ type: "text", text: "Correct the prose." }]);
  await f.cleanup();
});
test("error, unknown and empty steps reach neither the scanner nor a notice", async () => {
  const f = await fixture();
  f.ctx.session.context = async () => [
    { id: "empty", type: "assistant", content: [] },
    { id: "answer", type: "assistant", content: [{ type: "text", text: "Bad prose." }] },
  ];
  f.setDecision({ decision: "block", notice: "Revise the answer." });
  for (const [assistantMessageID, finish] of [["empty", "error"], ["empty", "unknown"], ["empty", "stop"]]) {
    f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID, finish } });
  }
  f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "answer", finish: "stop" } });
  await f.notice;
  await new Promise<void>((resolve) => setImmediate(resolve));
  assert.equal(f.notices.length, 1);
  assert.equal(f.payload().message.content, "Bad prose.");
  await f.cleanup();
});

async function quietly<T>(run: (errors: unknown[][]) => Promise<T>) {
  const original = console.error;
  const errors: unknown[][] = [];
  console.error = (...args: unknown[]) => { errors.push(args); };
  try { return await run(errors); } finally { console.error = original; }
}
const settle = () => new Promise<void>((resolve) => setImmediate(resolve));
const sessionHooks = ["context", "compaction", "generate", "title"];

test("a failed observation on one turn leaves later turns working", () => quietly(async (errors) => {
  const f = await fixture();
  try {
    f.ctx.session.context = async () => [];
    f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "answer", finish: "stop" } });
    await settle(); await settle();
    assert.ok(errors.some((args) => String(args[0]).startsWith("Communication Rules:")));
    f.ctx.session.context = async () => [{ id: "second", type: "assistant", content: [{ type: "text", text: "Bad prose." }] }];
    for (const hook of sessionHooks) await f.hooks[hook]({ sessionID: "session", system: [] });
    await f.hooks["execute.before"]({ tool: "write", input: {}, sessionID: "session" });
    f.setDecision({ decision: "block", notice: "Revise the second answer." });
    f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "second", finish: "stop" } });
    await f.notice;
    assert.equal(f.notices[0].text, "Revise the second answer.");
    f.setDecision({ decision: "pass" });
    for (const hook of sessionHooks) await f.hooks[hook]({ sessionID: "session", system: [] });
  } finally {
    await f.cleanup();
  }
}));
test("the observer accepts the older { data } client results", async () => {
  const f = await fixture();
  f.ctx.session.get = async ({ sessionID }: any) => ({ data: { id: sessionID, location: { directory: "/project" } } });
  f.ctx.session.context = async () => ({ data: [{ id: "answer", type: "assistant", content: [{ type: "text", text: "Bad prose." }] }] });
  f.setDecision({ decision: "block", notice: "Revise the answer." });
  f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "answer", finish: "stop" } });
  await f.notice;
  assert.equal(f.notices[0].text, "Revise the answer.");
  await f.cleanup();
});
test("session hooks never throw and fall back to the rules reminder", () => quietly(async (errors) => {
  const f = await fixture();
  for (const decision of [null, { decision: "block" }]) {
    if (decision) f.setDecision(decision); else f.corrupt();
    const event = { sessionID: "session", system: [] };
    await f.hooks.context(event);
    assert.deepEqual(event.system, [{ type: "text", text: "Rules reminder" }]);
  }
  assert.equal(errors.length, 2);
  await f.cleanup();
}));
for (const failure of ["closed", "rejected", "undefined", "scanner", "missing-message", "notice"]) {
  test(`observer failure (${failure}) is logged and blocks no later hook`, () => quietly(async (errors) => {
    const f = await fixture();
    if (failure === "closed") f.close();
    else if (failure === "rejected") f.fail(new Error("Stream failed"));
    else if (failure === "undefined") f.fail(undefined);
    else {
      if (failure === "scanner") f.corrupt();
      if (failure === "missing-message") f.ctx.session.context = async () => [];
      if (failure === "notice") {
        f.setDecision({ decision: "block", notice: "Revise the answer." });
        f.ctx.session.synthetic = async () => { throw new Error("Notice failed"); };
      }
      f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "answer", finish: "stop" } });
    }
    await settle(); await settle();
    assert.ok(errors.some((args) => String(args[0]).startsWith("Communication Rules:")));
    f.setDecision({ decision: "pass" });
    for (const hook of sessionHooks) await f.hooks[hook]({ sessionID: "session", system: [] });
    await f.hooks["execute.before"]({ tool: "write", input: {}, sessionID: "session" });
    await f.cleanup();
  }));
}
