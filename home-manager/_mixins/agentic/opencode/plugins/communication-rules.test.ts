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
            json.dump({"decision": "pass", "notice": ""}, f)
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
    scannerFails: (mode: string) => writeFileSync(scanner, `#!${python}\n${{
      timeout: "import time; time.sleep(10)",
      output: "print('x' * 100000)",
      exit: "raise SystemExit(1)",
    }[mode]}\n`, { mode: 0o755 }),
  };
}
test("V2 context adds compact advice once without changing messages", async () => {
  const f = await fixture();
  f.setDecision({ decision: "advisory", notice: "Use plain words." });
  const messages = [{ role: "tool", content: "Preserved source" }];
  const event = { sessionID: "session", system: [], messages };
  await f.hooks.context(event); await f.hooks.context(event);
  assert.deepEqual(event.system, [{ type: "text", text: "Use plain words." }]);
  assert.equal(event.messages, messages);
  await f.cleanup();
});
test("V2 prompt resets the budget without changing the prompt", async () => {
  const f = await fixture();
  const event = { sessionID: "session", messageID: "user-2", prompt: { text: "Exact user input" } };
  const original = structuredClone(event);
  await f.hooks.prompt(event);
  assert.deepEqual(event, original);
  assert.deepEqual(f.payload(), { sessionID: "session", turn_id: "user-2" });
  for (const hook of ["compaction", "generate", "title", "execute.after"]) assert.equal(f.hooks[hook], undefined);
  await f.cleanup();
});
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
test("old decisions, malformed responses and scanner errors preserve tool input", () => quietly(async (errors) => {
  const f = await fixture();
  const event = { tool: "write", input: { path: "/tmp/a", content: "Text" }, sessionID: "session" };
  const original = structuredClone(event);
  for (const decision of [null, [], { decision: "block", notice: "Revise." }, { decision: "unknown" }, { decision: "advisory", notice: {} }]) {
    f.setDecision(decision);
    assert.equal(await f.hooks["execute.before"](event), undefined);
    assert.deepEqual(event, original);
  }
  f.corrupt(); assert.equal(await f.hooks["execute.before"](event), undefined);
  assert.equal(errors.length, 1);
  assert.equal(f.notices.length, 0);
  await f.cleanup();
}));
test("advice is bounded once per turn and never resumes the session", async () => {
  const f = await fixture();
  const event = { tool: "write", input: { path: "/tmp/a", content: "Text" }, sessionID: "session" };
  f.setDecision({ decision: "advisory", notice: "x".repeat(1000) });
  await f.hooks["execute.before"](event);
  await f.hooks["execute.before"](event);
  assert.equal(f.notices.length, 1);
  assert.equal(f.notices[0].text.length, 320);
  await f.hooks.prompt({ sessionID: "session", messageID: "next" });
  await f.hooks["execute.before"](event);
  assert.equal(f.notices.length, 2);
  assert.ok(f.notices.every((item) => item.resume === false));
  await f.cleanup();
});
for (const failure of ["timeout", "output", "exit", "tool-list", "notice"]) {
  test(`tool handler failure (${failure}) leaves the tool unchanged`, () => quietly(async (errors) => {
    const f = await fixture();
    try {
      if (failure === "tool-list") f.ctx.tool.list = async () => { throw new Error("Unavailable"); };
      else if (failure === "notice") {
        f.setDecision({ decision: "advisory", notice: "Use plain words." });
        f.ctx.session.synthetic = async () => { throw new Error("Unavailable"); };
      } else f.scannerFails(failure);
      const event = { tool: "read", input: { path: "/source" }, sessionID: "session" };
      const original = structuredClone(event);
      assert.equal(await f.hooks["execute.before"](event), undefined);
      assert.deepEqual(event, original);
      assert.equal(errors.length, 1);
    } finally { await f.cleanup(); }
  }));
}
test("completed V2 prose is observed after display and queues a correction notice", async () => {
  const f = await fixture();
  f.setDecision({ decision: "advisory", notice: "Use plain words in the next reply." });
  f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "answer", finish: "stop" } });
  await f.notice;
  assert.equal(f.payload().message.content, "Bad prose.");
  assert.equal(f.payload().message.role, "assistant");
  assert.equal(f.notices[0].text, "Use plain words in the next reply.");
  assert.equal(f.notices[0].resume, false);
  f.setDecision({ decision: "advisory", notice: "Use plain words in the next reply." });
  const context = { sessionID: "session", system: [] };
  await f.hooks.context(context);
  assert.deepEqual(context.system, [{ type: "text", text: "Use plain words in the next reply." }]);
  await f.cleanup();
});
test("error, unknown and empty steps reach neither the scanner nor a notice", async () => {
  const f = await fixture();
  f.ctx.session.context = async () => [
    { id: "empty", type: "assistant", content: [] },
    { id: "answer", type: "assistant", content: [{ type: "text", text: "Bad prose." }] },
  ];
  f.setDecision({ decision: "advisory", notice: "Use plain words." });
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
const sessionHooks = ["context"];

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
    f.setDecision({ decision: "advisory", notice: "Use plain words." });
    f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "second", finish: "stop" } });
    await f.notice;
    assert.equal(f.notices[0].text, "Use plain words.");
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
  f.setDecision({ decision: "advisory", notice: "Use plain words." });
  f.send({ type: "session.step.ended", data: { sessionID: "session", assistantMessageID: "answer", finish: "stop" } });
  await f.notice;
  assert.equal(f.notices[0].text, "Use plain words.");
  await f.cleanup();
});
test("session hook errors preserve context and log one diagnostic", () => quietly(async (errors) => {
  const f = await fixture();
  for (const decision of [null, { decision: "block" }]) {
    if (decision) f.setDecision(decision); else f.corrupt();
    const event = { sessionID: "session", system: [] };
    await f.hooks.context(event);
    assert.deepEqual(event.system, []);
  }
  assert.equal(errors.length, 1);
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
        f.setDecision({ decision: "advisory", notice: "Use plain words." });
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
