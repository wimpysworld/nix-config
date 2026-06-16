// OpenCode shim seam test (Bun, run with `bun test`).
//
// Imports the REAL reduced plugin
// (`opencode/plugins/communication-rules.ts`) and drives its hooks. Each hook
// spawns the REAL Python core (`scanner.py opencode <event>`) the same way
// production does, so this exercises the seam, not a reimplementation. The
// plugin reads its paths from build-time tokens (`@tripwireScanner@`,
// `@tripwireRules@`, `@tripwireCorrectionPrompt@`); the test substitutes those
// into a temp copy, pointing the scanner token at a wrapper that execs the core
// with temp state dirs. All per-session state dirs (strike, reissue, injected)
// point at the temp dir, so the test is hermetic and order-independent.
//
// Two cases per acceptance criterion 8: a B2 yield maps to the right plugin
// outcome with `level = error` (and `surface = B2`, asserted against the raw
// core decision), and a Tier A facing case writes the live `output.text` and
// calls the toast, plus the system-transform hook injects the rules into the
// live `output.system` array.

import { afterAll, beforeAll, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const root = path.resolve(import.meta.dir, "..");
const scanner = path.join(root, "scanner.py");
const rulesSource = path.join(root, "communication-rules.md");
const pluginSource = path.resolve(
  root,
  "../../opencode/plugins/communication-rules.ts",
);

// A banned term, built from character codes so the literal never sits in this
// source (the core blocks any file that contains a banned word).
const BANNED = String.fromCharCode(108, 101, 118, 101, 114, 97, 103, 101);

// The short B2 nudge the core emits on the middle blocks of the external cap
// (strikes 2 .. limit - 2). Byte-identical to `core.state.EXTERNAL_REPEAT_NOTICE`.
const B2_REPEAT_NOTICE = "Communication Rules still unmet. Revise the body to comply before posting.";

interface Decision {
  decision: string;
  surface: string;
  level: string;
  notice: string;
  inject_base_rules: boolean;
  append_correction: boolean;
}

type ToastInput = { body: { message: string; variant?: string } };
interface Hooks {
  "experimental.chat.system.transform": (
    input: unknown,
    output: { system?: string[] },
  ) => Promise<void>;
  "tool.execute.before": (input: unknown, output: unknown) => Promise<void>;
  "experimental.text.complete": (
    input: unknown,
    output: { text?: string },
  ) => Promise<void>;
}

let tempDir: string;
let strikeDir: string;
let toasts: string[];

// Load the real plugin with its build-time tokens substituted: the scanner
// token points at a wrapper that execs the core with temp state dirs, so the
// file-backed counters are hermetic and shared across the shim's repeated
// spawns within one test. Records toast calls so the test asserts the side
// effect, not only the return.
async function loadShim(): Promise<Hooks> {
  toasts = [];
  const client = {
    tui: {
      async showToast(input: ToastInput): Promise<void> {
        toasts.push(input.body.message);
      },
    },
  };
  const mod = (await import(`${tempDir}/plugin.ts?${Date.now()}`)) as {
    CommunicationRules: (ctx: { client?: unknown }) => Promise<Hooks>;
  };
  return mod.CommunicationRules({ client });
}

// Load a plugin copy whose scanner token points at a STUB core that always
// prints the given decision JSON. This exercises the shim's decision mapping for
// a value the real core never emits (an unknown decision), so the test can prove
// the gating surface fails closed. Returns the loaded hooks.
async function loadShimWithStubDecision(decisionJson: string): Promise<Hooks> {
  toasts = [];
  const stub = path.join(tempDir, `stub-core-${Date.now()}`);
  fs.writeFileSync(
    stub,
    ["#!/usr/bin/env bash", `printf '%s' ${`'${decisionJson.replaceAll("'", "'\\''")}'`}`, ""].join("\n"),
    "utf-8",
  );
  fs.chmodSync(stub, 0o755);
  const pluginText = fs
    .readFileSync(pluginSource, "utf-8")
    .replaceAll("@tripwireScanner@", stub)
    .replaceAll("@tripwireRules@", path.join(tempDir, "rules.md"))
    .replaceAll("@tripwireCorrectionPrompt@", path.join(tempDir, "correction-prompt.md"));
  const pluginFile = path.join(tempDir, `plugin-stub-${Date.now()}.ts`);
  fs.writeFileSync(pluginFile, pluginText, "utf-8");
  const client = {
    tui: {
      async showToast(input: ToastInput): Promise<void> {
        toasts.push(input.body.message);
      },
    },
  };
  const mod = (await import(`${pluginFile}?${Date.now()}`)) as {
    CommunicationRules: (ctx: { client?: unknown }) => Promise<Hooks>;
  };
  return mod.CommunicationRules({ client });
}

// Probe the raw core decision the same way the shim spawns it, so the test can
// assert `surface`, which the plugin outcome does not carry.
function coreDecision(event: string, payload: unknown): Decision {
  const wrapper = path.join(tempDir, "core-wrapper");
  const r = spawnSync(wrapper, ["opencode", event], {
    encoding: "utf-8",
    input: JSON.stringify(payload),
  });
  return JSON.parse((r.stdout ?? "").trim()) as Decision;
}

function b2Payload(): unknown {
  return {
    event: "tool.execute.before",
    tool: { name: "gh-api-safe" },
    args: {
      command: `gh-api-safe repos/x/issues/1/comments -X POST -f body='This body shows ${BANNED}.'`,
    },
  };
}

// A B1 write to a stable file path with breaching content. The path is the
// strike target, so two writes to the SAME path share the strike key: the
// first blocks, the second (and later) allow-revise.
const B1_TARGET = "/tmp/comm-rules-b1-revise.md";
function b1WritePayload(): { input: unknown; output: { args: unknown } } {
  return {
    input: { tool: { name: "write" } },
    output: { args: { file_path: B1_TARGET, content: `We should ${BANNED} this.` } },
  };
}

beforeAll(() => {
  tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "opencode-shim-test-"));
  strikeDir = path.join(tempDir, "strikes");

  const rules = fs.readFileSync(rulesSource, "utf-8").trim();
  const rulesPath = path.join(tempDir, "rules.md");
  const correctionPromptPath = path.join(tempDir, "correction-prompt.md");
  fs.writeFileSync(rulesPath, `${rules}\n`, "utf-8");
  fs.writeFileSync(
    correctionPromptPath,
    `Your previous reply broke the Communication Rules. Apply them to this reply and every reply that follows. Do not resend or rewrite the previous reply.\n\nCommunication Rules:\n${rules}\n`,
    "utf-8",
  );

  // The wrapper is the scanner token: it runs the core with temp state dirs so
  // strikes, reissue flags, and injected-rules flags do not leak and survive
  // across the shim's spawns within a test.
  const wrapper = path.join(tempDir, "core-wrapper");
  const q = (value: string): string => `'${value.replaceAll("'", "'\\''")}'`;
  fs.writeFileSync(
    wrapper,
    [
      "#!/usr/bin/env bash",
      "set -euo pipefail",
      `export TRIPWIRE_STRIKE_DIR=${q(strikeDir)}`,
      `export TRIPWIRE_REISSUE_DIR=${q(path.join(tempDir, "reissue"))}`,
      `export TRIPWIRE_INJECTED_DIR=${q(path.join(tempDir, "injected"))}`,
      `exec python3 ${q(scanner)} --rules ${q(rulesPath)} "$@"`,
      "",
    ].join("\n"),
    "utf-8",
  );
  fs.chmodSync(wrapper, 0o755);

  // Substitute the plugin's build-time tokens and write the copy the test
  // imports, so it loads the REAL shim logic against the temp wrapper.
  const pluginText = fs
    .readFileSync(pluginSource, "utf-8")
    .replaceAll("@tripwireScanner@", wrapper)
    .replaceAll("@tripwireRules@", rulesPath)
    .replaceAll("@tripwireCorrectionPrompt@", correctionPromptPath);
  fs.writeFileSync(path.join(tempDir, "plugin.ts"), pluginText, "utf-8");
});

afterAll(() => {
  fs.rmSync(tempDir, { recursive: true, force: true });
});

test("B2 yield: tool.execute.before walks the cap then yields with level=error, surface=B2", async () => {
  const hooks = await loadShim();
  const before = hooks["tool.execute.before"];

  // The raw core decision confirms the surface, which the plugin outcome omits.
  const firstDecision = coreDecision("tool.execute.before", b2Payload());
  expect(firstDecision.surface).toBe("B2");
  expect(firstDecision.level).toBe("error");

  // Strikes two to four block: the shim throws. The probe above consumed strike
  // 1, so the handler sees strikes 2, 3, 4. The re-issue trim throws the short
  // nudge on the middle blocks (strikes 2 and 3) and the full rules on the
  // penultimate block (strike 4); the shim maps the thrown message from the wire
  // notice, falling back to the full block message when the notice is empty.
  for (let strike = 2; strike <= 4; strike += 1) {
    const call = before(b2Payload(), { args: (b2Payload() as { args: unknown }).args });
    if (strike < 4) {
      await expect(call).rejects.toThrow(B2_REPEAT_NOTICE);
    } else {
      await expect(call).rejects.toThrow(/Communication Rules/);
    }
  }
  // The fifth yields: the shim returns (no throw) and toasts at error level.
  const toastsBefore = toasts.length;
  await before(b2Payload(), { args: (b2Payload() as { args: unknown }).args });
  const yielded = toasts.slice(toastsBefore);
  expect(yielded.length).toBe(1);
  expect(yielded[0]).toMatch(/gh-api-safe/);
});

test("B1 allow-revise: a repeat write to the same path lands (no throw) and toasts the revision notice, surface=B1", async () => {
  const hooks = await loadShim();
  const before = hooks["tool.execute.before"];

  // Strike 1 on this path blocks: the shim throws (one cheap attempt before the
  // write lands).
  const first = b1WritePayload();
  await expect(before(first.input, first.output)).rejects.toThrow();

  // The raw core decision confirms the allow shape and surface the plugin
  // outcome omits: strike >= 2 on the same target is allow-revise on B1.
  const decision = coreDecision("tool.execute.before", {
    event: "tool.execute.before",
    tool: { name: "write" },
    args: { file_path: B1_TARGET, content: `We should ${BANNED} this.` },
  });
  expect(decision.surface).toBe("B1");
  expect(decision.decision).toBe("allow-revise");

  // A later breach to the same path lands: the shim returns (no throw) and
  // toasts the resolved revision notice, which names the file.
  const repeat = b1WritePayload();
  const toastsBefore = toasts.length;
  await before(repeat.input, repeat.output);
  const revised = toasts.slice(toastsBefore);
  expect(revised.length).toBe(1);
  expect(revised[0]).toContain(B1_TARGET);
});

test("Tier A facing: text.complete writes live output.text and toasts", async () => {
  const hooks = await loadShim();
  const complete = hooks["experimental.text.complete"];

  // The raw core decision carries the facing notice the shim appends.
  const decision = coreDecision("message.final", {
    event: "message.final",
    surface: "final",
    message: { content: `We should ${BANNED} this.` },
  });
  expect(decision.notice).not.toBe("");

  // The shim appends the notice to the live output.text and toasts; assert the
  // live object grew, not only the return.
  const output = { text: `We should ${BANNED} this.` };
  const toastsBefore = toasts.length;
  await complete({ event: "message.final" }, output);
  expect(output.text).toContain(decision.notice);
  expect(toasts.length).toBe(toastsBefore + 1);
});

test("Default-deny: an unknown decision on tool.execute.before throws, a clean pass allows", async () => {
  // An unrecognised decision on this gating surface must fail closed: the shim
  // throws (default-deny), matching Tier B fail-closed.
  const unknown = await loadShimWithStubDecision(
    JSON.stringify({
      decision: "surprise",
      surface: "B1",
      level: "warning",
      notice: "",
      inject_base_rules: false,
      append_correction: false,
      block_message: "",
    }),
  );
  await expect(
    unknown["tool.execute.before"]({ tool: { name: "write" } }, { args: {} }),
  ).rejects.toThrow();

  // A clean pass still allows the tool to run: the shim returns without throwing
  // and emits no toast.
  const clean = await loadShimWithStubDecision(
    JSON.stringify({
      decision: "pass",
      surface: "B1",
      level: "warning",
      notice: "",
      inject_base_rules: false,
      append_correction: false,
      block_message: "",
    }),
  );
  const toastsBefore = toasts.length;
  await clean["tool.execute.before"]({ tool: { name: "write" } }, { args: {} });
  expect(toasts.length).toBe(toastsBefore);
});

test("Tier A inject: chat.system.transform pushes the rules into live output.system", async () => {
  const hooks = await loadShim();
  const transform = hooks["experimental.chat.system.transform"];

  // A fresh session injects the base rules once into the live system array.
  const decision = coreDecision("context", {
    event: "chat.system.transform",
    session_id: "oc-ctx-probe",
    messages: [],
  });
  expect(decision.inject_base_rules).toBe(true);

  // The handler call must use a distinct session; the file-backed inject dedupe
  // is per session, so the probe above would otherwise consume the one shot.
  const output: { system?: string[] } = {};
  await transform(
    { event: "chat.system.transform", sessionID: "oc-ctx-handler" },
    output,
  );
  expect(Array.isArray(output.system)).toBe(true);
  expect(output.system!.length).toBe(1);
  expect(output.system![0]).toMatch(/Communication Rules:/);
});
