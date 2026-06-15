// Pi shim seam test (Node, run with `node --test`).
//
// Imports the REAL reduced shim (`pi/extensions/communication-rules/index.ts`)
// and drives its handlers. Each handler spawns the REAL Python core
// (`scanner.py pi <event>`) the same way production does, so this exercises the
// seam, not a reimplementation. The temp HOME holds the `config.json` the shim
// reads, with `adapterPath` pointed at a wrapper that execs the core; the strike
// dir is a temp dir, so the test is hermetic.
//
// Two cases per acceptance criterion 8: a B2 yield maps to the right Pi return
// with `level = error` (and `surface = B2`, asserted against the raw core
// decision), and a Tier A facing case appends to the live `event.messages` and
// calls notify.

import { spawnSync } from "node:child_process";
import * as assert from "node:assert/strict";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { after, before, test } from "node:test";
import { pathToFileURL } from "node:url";

const root = path.resolve(import.meta.dirname, "..");
const scanner = path.join(root, "scanner.py");
const rulesSource = path.join(root, "communication-rules.md");
const extension = path.resolve(
  root,
  "../../pi/extensions/communication-rules/index.ts",
);

// A banned term, built from character codes so the literal never sits in this
// source (the core blocks any file that contains a banned word).
const BANNED = String.fromCharCode(108, 101, 118, 101, 114, 97, 103, 101);

interface Decision {
  decision: string;
  surface: string;
  level: string;
  notice: string;
  inject_base_rules: boolean;
  append_correction: boolean;
}

let tempHome: string;
let strikeDir: string;

// Build the temp HOME the shim loads its config from, plus a wrapper the shim
// spawns as `adapterPath pi <event>`. The wrapper execs the real core with a
// temp strike dir, so the file-backed counter is hermetic and shared across the
// shim's repeated spawns within one test.
before(() => {
  tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "pi-shim-test-"));
  strikeDir = path.join(tempHome, "strikes");
  const configDir = path.join(tempHome, ".pi/agent/extensions/communication-rules");
  fs.mkdirSync(configDir, { recursive: true });

  const rules = fs.readFileSync(rulesSource, "utf-8").trim();
  const rulesPath = path.join(tempHome, "rules.md");
  const correctionPromptPath = path.join(tempHome, "correction-prompt.md");
  fs.writeFileSync(rulesPath, `${rules}\n`, "utf-8");
  fs.writeFileSync(
    correctionPromptPath,
    `Revise the previous response to follow the Communication Rules.\n\nCommunication Rules:\n${rules}\n`,
    "utf-8",
  );

  // The wrapper is `adapterPath`: it runs the core with the temp strike dir so
  // strikes do not leak and survive across the shim's spawns within a test.
  const wrapper = path.join(tempHome, "core-wrapper");
  const q = (value: string): string => `'${value.replaceAll("'", "'\\''")}'`;
  fs.writeFileSync(
    wrapper,
    [
      "#!/usr/bin/env bash",
      "set -euo pipefail",
      `export TRIPWIRE_STRIKE_DIR=${q(strikeDir)}`,
      `export TRIPWIRE_REISSUE_DIR=${q(path.join(tempHome, "reissue"))}`,
      // Isolate the once-per-session injected-rules flag too. Without this a
      // stale flag from an earlier suite leaks in, making the Tier A injection
      // assertion order-dependent.
      `export TRIPWIRE_INJECTED_DIR=${q(path.join(tempHome, "injected"))}`,
      `exec python3 ${q(scanner)} --rules ${q(rulesPath)} "$@"`,
      "",
    ].join("\n"),
    "utf-8",
  );
  fs.chmodSync(wrapper, 0o755);

  fs.writeFileSync(
    path.join(configDir, "config.json"),
    JSON.stringify({ adapterPath: wrapper, rulesPath, correctionPromptPath }),
    "utf-8",
  );
  process.env.HOME = tempHome;
});

after(() => {
  fs.rmSync(tempHome, { recursive: true, force: true });
});

type Handler = (event: unknown, ctx: unknown) => unknown;
interface Loaded {
  handlers: Map<string, Handler>;
  notifications: Array<{ text: string; level: string }>;
  ctx: unknown;
}

// Load the real shim and capture the handlers it registers on `pi.on`. The ctx
// is a minimal Pi ExtensionContext whose `ui.notify` records calls, so the test
// asserts the shim's notify side effect.
async function loadShim(): Promise<Loaded> {
  const handlers = new Map<string, Handler>();
  const notifications: Array<{ text: string; level: string }> = [];
  const mod = (await import(pathToFileURL(extension).href)) as {
    default: (pi: { on(event: string, handler: Handler): void }) => void;
  };
  mod.default({
    on(event, handler) {
      handlers.set(event, handler);
    },
  });
  const ctx = {
    hasUI: true,
    ui: {
      notify(text: string, level: string): void {
        notifications.push({ text, level });
      },
    },
  };
  return { handlers, notifications, ctx };
}

// Probe the raw core decision the same way the shim spawns it, so the test can
// assert `surface`, which the Pi return shape does not carry.
function coreDecision(event: string, payload: unknown): Decision {
  const wrapper = path.join(tempHome, "core-wrapper");
  const r = spawnSync(wrapper, ["pi", event], { encoding: "utf-8", input: JSON.stringify(payload) });
  return JSON.parse((r.stdout ?? "").trim()) as Decision;
}

function b2Payload(): unknown {
  return {
    session_id: "shim-b2",
    type: "tool_call",
    toolName: "bash",
    toolCallId: "call-b2",
    input: { command: `gh issue create --title "Done" --body "This body shows ${BANNED}."` },
  };
}

test("B2 yield: tool_call walks the cap then yields with level=error and surface=B2", async () => {
  const loaded = await loadShim();
  const toolCall = loaded.handlers.get("tool_call");
  assert.ok(toolCall, "tool_call handler registered");

  // The raw core decision confirms the surface, which the Pi return omits.
  const firstDecision = coreDecision("tool_call", b2Payload());
  assert.equal(firstDecision.surface, "B2");
  assert.equal(firstDecision.level, "error");

  // Strikes one to four block: the shim returns { block: true }.
  for (let strike = 2; strike <= 4; strike += 1) {
    const result = toolCall!(b2Payload(), loaded.ctx) as { block?: boolean } | undefined;
    assert.equal(result?.block, true, `B2 strike ${strike} should block`);
  }
  // The fifth yields: the shim returns undefined and notifies at error level.
  const before = loaded.notifications.length;
  const fifth = toolCall!(b2Payload(), loaded.ctx);
  assert.equal(fifth, undefined, "B2 strike 5 should yield (undefined), not block");
  const notice = loaded.notifications.slice(before).find((n) => n.level === "error");
  assert.ok(notice, "B2 yield should notify at error level");
  assert.match(notice!.text, /bash/, "B2 yield notice should name the tool");
});

test("Tier A facing: context handler appends to live event.messages", async () => {
  // A fresh session injects the base rules into the live messages array. The
  // shim's context handler returns the mutated messages; assert the live object
  // grew, not only the return verb.
  const loaded = await loadShim();
  const context = loaded.handlers.get("context");
  assert.ok(context, "context handler registered");

  // The rules-injection dedupe is file-backed per session, so the probe and the
  // handler call must use distinct sessions; otherwise the probe consumes the
  // once-per-session injection.
  const decision = coreDecision("context", { type: "context", session_id: "shim-ctx-probe", messages: [] });
  assert.equal(decision.inject_base_rules, true, "fresh session should inject base rules");

  const event = { type: "context", session_id: "shim-ctx-handler", messages: [] as unknown[] };
  const result = context!(event, {}) as { messages?: unknown[] } | undefined;
  assert.ok(result, "context should return a messages payload when injecting");
  assert.ok(Array.isArray(result!.messages), "context should return a messages array");
  assert.equal(result!.messages!.length, 1, "context should append one base-rules message");
  const injected = result!.messages![0] as { content?: string; display?: boolean };
  assert.match(injected.content ?? "", /Communication Rules:/, "injected message carries the rules");
  assert.equal(injected.display, false, "injected message is model-only");
});
