// Gate: checks.<system>.communication-rules-hooks runs bun test on this file.
import { test } from "bun:test";
import assert from "node:assert/strict";
import { breach, diagnostics, loadOpenCode, scannerFixture } from "./shim-support.ts";

const publication = () => ({
  sessionID: "oc-session", tool: "github_create_issue",
  input: { title: "Build status", body: breach },
});

test("OpenCode permits publications and does not resume a session for style", async () => {
  const f = scannerFixture();
  const p = await loadOpenCode(f);
  try {
    const event = publication();
    const original = structuredClone(event);
    for (let attempt = 0; attempt < 7; attempt += 1) {
      assert.equal(await p.hooks["execute.before"](event), undefined);
      assert.deepEqual(event, original);
      await p.hooks["execute.before"]({
        sessionID: "oc-session", tool: "mcp__github__get_pull_request_review",
        input: { id: "review-42", text: breach },
      });
    }
    assert.equal(p.notices.length, 1);
    assert.equal(p.notices[0].resume, false);
    assert.ok(p.notices[0].text.length <= 320);
  } finally { await p.cleanup(); f.cleanup(); }
});

test("OpenCode observes final text without rewriting it and consumes pending context once", async () => {
  const f = scannerFixture();
  const p = await loadOpenCode(f);
  try {
    await p.hooks.prompt({ sessionID: "oc-session", messageID: "one" });
    const messages = await p.context.session.context();
    const original = structuredClone(messages);
    await p.final();
    assert.deepEqual(await p.context.session.context(), original);
    assert.equal(p.notices.length, 1);
    assert.equal(p.notices[0].resume, false);
    await p.hooks.prompt({ sessionID: "oc-session", messageID: "two" });
    const imported = [{ role: "tool", content: breach }];
    const event = { sessionID: "oc-session", system: [], messages: imported };
    await p.hooks.context(event);
    assert.equal(event.system.length, 1);
    assert.ok(event.system[0].text.length <= 320);
    assert.equal(event.messages, imported);
    assert.deepEqual(imported, [{ role: "tool", content: breach }]);
    await p.hooks.context(event);
    assert.equal(event.system.length, 1);
  } finally { await p.cleanup(); f.cleanup(); }
});

test("OpenCode has no result, display-rewrite or permission hooks", async () => {
  const f = scannerFixture();
  const p = await loadOpenCode(f);
  try {
    assert.deepEqual(Object.keys(p.hooks).sort(), ["context", "execute.before", "prompt"]);
  } finally { await p.cleanup(); f.cleanup(); }
});

test("OpenCode checker decisions cannot reject or authorise the request", () => diagnostics(async (errors) => {
  const f = scannerFixture();
  const p = await loadOpenCode(f);
  try {
    const event = publication();
    const original = structuredClone(event);
    for (const decision of [
      null, [], { decision: "block" }, { decision: "allow-revise" },
      { decision: "surprise" }, { decision: "advisory", notice: {} },
    ]) {
      f.response(decision);
      assert.equal(await p.hooks["execute.before"](event), undefined);
      assert.deepEqual(event, original);
    }
    assert.equal(errors.length, 1);
    assert.equal(p.notices.length, 0);
  } finally { await p.cleanup(); f.cleanup(); }
}));

for (const mode of ["malformed", "exit", "timeout", "overflow"]) {
  test("OpenCode checker failure preserves the operation: " + mode, () => diagnostics(async (errors) => {
    const f = scannerFixture();
    const p = await loadOpenCode(f);
    try {
      f.mode(mode);
      const event = publication();
      const original = structuredClone(event);
      assert.equal(await p.hooks["execute.before"](event), undefined);
      assert.deepEqual(event, original);
      assert.equal(errors.length, 1);
      assert.equal(p.notices.length, 0);
    } finally { await p.cleanup(); f.cleanup(); }
  }));
}

test("OpenCode missing scanner preserves the request without permission fields", () => diagnostics(async (errors) => {
  const f = scannerFixture();
  const p = await loadOpenCode(f);
  try {
    f.cleanup();
    assert.equal(await p.hooks["execute.before"](publication()), undefined);
    assert.equal(errors.length, 1);
    assert.equal(p.notices.length, 0);
  } finally { await p.cleanup(); f.cleanup(); }
}));
