// Gate: checks.<system>.communication-rules-hooks runs node --test on this file.
import assert from "node:assert/strict";
import { test } from "node:test";
import { breach, diagnostics, loadPi, scannerFixture } from "./shim-support.ts";

const publication = () => ({
  type: "tool_call", toolName: "mcp__github__create_issue",
  input: { body: breach, title: "Build status" },
});

test("Pi permits repeated publication requests and sends one bounded notice", async () => {
  const f = scannerFixture();
  try {
    const p = await loadPi(f);
    const event = publication();
    const original = structuredClone(event);
    for (let attempt = 0; attempt < 7; attempt += 1) {
      assert.equal(await p.handlers.get("tool_call")!(event, p.context), undefined);
      assert.deepEqual(event, original);
      await p.handlers.get("tool_call")!({
        toolName: "mcp__github__get_pull_request_review", input: { id: "review-42", text: breach },
      }, p.context);
    }
    assert.equal(p.notices.length, 1);
    assert.ok(p.notices[0].text.length <= 320);
    assert.ok(!p.notices[0].text.includes("## The Cut Pass"));
  } finally { f.cleanup(); }
});

test("Pi preserves final text and consumes one pending notice on the next normal context", async () => {
  const f = scannerFixture();
  try {
    const p = await loadPi(f);
    await p.handlers.get("before_agent_start")!({}, p.context);
    const message = { role: "assistant", content: [{ type: "text", text: breach }], stopReason: "stop" };
    const original = structuredClone(message);
    assert.equal(await p.handlers.get("message_end")!({ message }, p.context), undefined);
    assert.deepEqual(message, original);
    await p.handlers.get("before_agent_start")!({}, p.context);
    const imported = [{ role: "tool", content: breach }];
    const event = { messages: imported };
    const result = await p.handlers.get("context")!(event, p.context);
    assert.equal(event.messages, imported);
    assert.equal(imported.length, 1);
    assert.equal(result.messages.length, 2);
    assert.equal(result.messages[0], imported[0]);
    assert.equal(result.messages[1].display, false);
    assert.ok(result.messages[1].content.length <= 320);
    assert.equal(await p.handlers.get("context")!(event, p.context), undefined);
  } finally { f.cleanup(); }
});

test("Pi never registers incoming-result or rewrite handlers", async () => {
  const f = scannerFixture();
  try {
    const p = await loadPi(f);
    assert.equal(p.handlers.get("tool_result"), undefined);
    const originalCalls = f.calls().length;
    await p.handlers.get("message_end")!({
      message: { role: "tool", content: [{ type: "text", text: breach }] },
    }, p.context);
    assert.equal(f.calls().length, originalCalls);
    assert.deepEqual([...p.handlers.keys()].sort(),
      ["before_agent_start", "context", "message_end", "tool_call"].sort());
  } finally { f.cleanup(); }
});

test("Pi rejects no tool for legacy, unknown or invalid scanner decisions", () => diagnostics(async (errors) => {
  const f = scannerFixture();
  try {
    const p = await loadPi(f);
    const event = publication();
    const original = structuredClone(event);
    for (const decision of [
      null, [], { decision: "block" }, { decision: "allow-revise" },
      { decision: "surprise" }, { decision: "advisory", notice: {} },
    ]) {
      f.response(decision);
      assert.equal(await p.handlers.get("tool_call")!(event, p.context), undefined);
      assert.deepEqual(event, original);
    }
    assert.equal(errors.length, 1);
    assert.equal(p.notices.length, 0);
  } finally { f.cleanup(); }
}));

for (const mode of ["malformed", "exit", "timeout", "overflow"]) {
  test("Pi checker failure preserves the operation: " + mode, () => diagnostics(async (errors) => {
    const f = scannerFixture();
    try {
      const p = await loadPi(f);
      f.mode(mode);
      const event = publication();
      const original = structuredClone(event);
      assert.equal(await p.handlers.get("tool_call")!(event, p.context), undefined);
      assert.deepEqual(event, original);
      assert.equal(errors.length, 1);
      assert.equal(p.notices.length, 0);
    } finally { f.cleanup(); }
  }));
}

test("Pi missing scanner preserves the tool and never grants authority", () => diagnostics(async (errors) => {
  const f = scannerFixture();
  try {
    const p = await loadPi(f);
    f.cleanup();
    const event = publication();
    assert.equal(await p.handlers.get("tool_call")!(event, p.context), undefined);
    assert.equal(errors.length, 1);
    assert.equal(p.notices.length, 0);
  } finally { f.cleanup(); }
}));
