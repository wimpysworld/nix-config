// Helpers for the gated Node and Bun adapter suites.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { pathToFileURL } from "node:url";

export const root = path.resolve(import.meta.dirname, "..");
export const breach = "Please " + "del" + "ve" + " into this.";
let serial = 0;

export function scannerFixture() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "communication-rules-shim-"));
  const python = spawnSync("python3", ["-c", "import sys; print(sys.executable)"], { encoding: "utf8" });
  assert.equal(python.status, 0, python.stderr);
  const modeFile = path.join(directory, "mode");
  const logFile = path.join(directory, "calls.jsonl");
  const responseFile = path.join(directory, "response.json");
  const scanner = path.join(directory, "scanner");
  fs.writeFileSync(modeFile, "real");
  fs.writeFileSync(responseFile, JSON.stringify({ decision: "pass", notice: "" }));
  const rules = path.resolve(root, "../../assistants/styles/house-style/house-style.md");
  fs.writeFileSync(scanner, [
    "#!" + python.stdout.trim(),
    "import json, os, pathlib, subprocess, sys, threading",
    "mode = pathlib.Path(" + JSON.stringify(modeFile) + ").read_text()",
    "raw = sys.stdin.read()",
    "with open(" + JSON.stringify(logFile) + ", 'a') as log:",
    "    log.write(json.dumps({'args': sys.argv[1:], 'payload': json.loads(raw)}) + '\\n')",
    "if mode == 'real':",
    "    os.environ['COMMUNICATION_RULES_STATE_DIR'] = " + JSON.stringify(path.join(directory, "state")),
    "    sys.exit(subprocess.run([sys.executable, " + JSON.stringify(path.join(root, "scanner.py")) + ", '--rules', " + JSON.stringify(rules) + "] + sys.argv[1:], input=raw, text=True, check=False).returncode)",
    "if mode == 'timeout': threading.Event().wait(10)",
    "if mode == 'exit': sys.exit(7)",
    "if mode == 'malformed': print('{'); sys.exit(0)",
    "if mode == 'overflow': print('x' * 1000000); sys.exit(0)",
    "print(pathlib.Path(" + JSON.stringify(responseFile) + ").read_text())",
    "",
  ].join("\n"), { mode: 0o755 });
  return {
    directory, scanner,
    mode(value: string) { fs.writeFileSync(modeFile, value); },
    response(value: unknown) {
      fs.writeFileSync(modeFile, "stub");
      fs.writeFileSync(responseFile, JSON.stringify(value));
    },
    calls() {
      return fs.existsSync(logFile)
        ? fs.readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line))
        : [];
    },
    cleanup() { fs.rmSync(directory, { recursive: true, force: true }); },
  };
}

export async function loadPi(fixture: ReturnType<typeof scannerFixture>) {
  const previousHome = process.env.HOME;
  process.env.HOME = fixture.directory;
  const configDir = path.join(fixture.directory, ".pi/agent/extensions/communication-rules");
  fs.mkdirSync(configDir, { recursive: true });
  fs.writeFileSync(path.join(configDir, "config.json"), JSON.stringify({ adapterPath: fixture.scanner }));
  const handlers = new Map<string, Function>();
  const notices: any[] = [];
  const api = {
    on(name: string, handler: Function) { handlers.set(name, handler); },
    sendMessage() { throw new Error("A style check must not send a message."); },
    sendUserMessage() { throw new Error("A style check must not start a turn."); },
  };
  try {
    const source = path.resolve(root, "../../pi/extensions/communication-rules/index.ts");
    const module = await import(pathToFileURL(source).href + "?test=" + (++serial));
    module.default(api);
  } finally {
    if (previousHome === undefined) delete process.env.HOME;
    else process.env.HOME = previousHome;
  }
  const context = {
    hasUI: true,
    sessionManager: { getSessionId: () => "pi-session" },
    ui: { notify(text: string, level: string) { notices.push({ text, level }); } },
  };
  return { handlers, notices, context };
}

export async function loadOpenCode(fixture: ReturnType<typeof scannerFixture>) {
  const source = path.resolve(root, "../../opencode/plugins/communication-rules.ts");
  const pluginPath = path.join(fixture.directory, "plugin.ts");
  fs.writeFileSync(pluginPath, fs.readFileSync(source, "utf8").replaceAll("@tripwireScanner@", fixture.scanner));
  const module = await import(pathToFileURL(pluginPath).href + "?test=" + (++serial));
  const hooks: Record<string, Function> = {};
  const notices: any[] = [];
  let controller: ReadableStreamDefaultController;
  const stream = new ReadableStream({ start(value) { controller = value; } });
  let noticeResolve: (() => void) | undefined;
  const context = {
    location: { directory: "/project" },
    session: {
      hook: async (name: string, callback: Function) => { hooks[name] = callback; },
      synthetic: async (value: any) => { notices.push(value); noticeResolve?.(); },
      get: async ({ sessionID }: any) => ({ id: sessionID, location: { directory: "/project" } }),
      context: async () => [{
        id: "answer", type: "assistant",
        content: [{ type: "text", text: breach }],
      }],
    },
    tool: {
      hook: async (name: string, callback: Function) => { hooks[name] = callback; },
      list: async () => [{
        id: "github_create_issue", name: "create_issue", options: { namespace: "github" },
      }],
    },
    event: {
      subscribe: ({ signal }: any) => {
        signal.addEventListener("abort", () => controller.close(), { once: true });
        return stream;
      },
    },
  };
  const close = await module.default.setup(context);
  return {
    hooks, notices, context,
    final() {
      const result = new Promise<void>((resolve) => { noticeResolve = resolve; });
      controller.enqueue({
        type: "session.step.ended",
        data: { sessionID: "oc-session", assistantMessageID: "answer", finish: "stop" },
      });
      return result;
    },
    async cleanup() { await close(); },
  };
}

export async function diagnostics(run: (errors: unknown[][]) => Promise<void>) {
  const original = console.error;
  const errors: unknown[][] = [];
  console.error = (...args: unknown[]) => { errors.push(args); };
  try { await run(errors); } finally { console.error = original; }
}
