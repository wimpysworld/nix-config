import { readFileSync } from "node:fs";

// Thin shim. All policy lives in the Python core; each hook spawns
// `core opencode <event>` and maps the decision to OpenCode's return/throw. The
// system, text, toast, and log writes are the one named exception to "zero logic
// in TS": runtime glue applying the core's flags, notice, and level. The Nix wiring substitutes these tokens at build time.
const scannerPath = "@tripwireScanner@";
const rulesPath = "@tripwireRules@";
const correctionPromptPath = "@tripwireCorrectionPrompt@";

const FALLBACK_BLOCK = "Blocked. Revise this prose to follow the Communication Rules.";

type Decision = {
  decision: string;
  surface: string;
  notice: string;
  level: string;
  inject_base_rules: boolean;
  append_correction: boolean;
  block_message: string;
};
type PluginClient = {
  tui?: { showToast?: (input: { body: { message: string; variant?: string } }) => Promise<unknown> };
  app?: { log?: (input: { body: Record<string, unknown> }) => Promise<unknown> };
};

function readText(file: string): string {
  try { return readFileSync(file, "utf-8").trimEnd(); } catch { return ""; }
}
// Spawn the core and parse its one-line decision; a failed spawn fails closed.
function decide(event: string, payload: unknown): Decision {
  const r = Bun.spawnSync([scannerPath, "opencode", event], {
    stdin: new Response(JSON.stringify(payload ?? {})), stdout: "pipe", stderr: "pipe",
  });
  try {
    if (r.exitCode === 0) return JSON.parse(new TextDecoder().decode(r.stdout).trim()) as Decision;
  } catch { /* fall through */ }
  return { decision: "block", surface: "B1", notice: "", level: "error", inject_base_rules: false, append_correction: false, block_message: "" };
}
async function toast(client: PluginClient | undefined, message: string): Promise<void> {
  if (!message) return;
  try { await client?.tui?.showToast?.({ body: { message, variant: "error" } }); } catch { /* fall through */ }
  try { await client?.app?.log?.({ body: { service: "communication-rules", level: "warn", message } }); } catch { /* ignore */ }
}

export const CommunicationRules = async (context: { client?: PluginClient } = {}) => {
  const client = context.client;
  return {
    "experimental.chat.system.transform": async (input: unknown, output: { system?: string[] }) => {
      const d = decide("context", input);
      output.system ??= [];
      if (d.inject_base_rules) {
        const section = `Communication Rules:\n${readText(rulesPath)}`;
        if (!output.system.includes(section)) output.system.push(section);
      }
      if (d.append_correction) {
        const correction = readText(correctionPromptPath);
        if (correction && !output.system.includes(correction)) output.system.push(correction);
      }
    },
    "tool.execute.before": async (input: unknown, output: unknown) => {
      const d = decide("tool.execute.before", { event: "tool.execute.before", ...(input as object), args: (output as { args?: unknown })?.args ?? {} });
      // B2 yield and B1 allow-revise both allow the write: toast and return.
      if (d.decision === "yield" || d.decision === "allow-revise") { void toast(client, d.notice); return; }
      if (d.decision === "block") throw new Error(d.block_message || FALLBACK_BLOCK);
    },
    "experimental.text.complete": async (input: unknown, output: { text?: string }) => {
      const d = decide("message.final", { event: "message.final", surface: "final", ...(input as object), message: { content: output.text ?? "" } });
      if (d.notice && typeof output.text === "string" && !output.text.includes(d.notice)) {
        output.text = `${output.text.trimEnd()}\n\n${d.notice}`;
      }
      if (d.notice) void toast(client, d.notice);
    },
    event: async (input: unknown) => {
      const d = decide("subagent.final", { event: "subagent.final", surface: "subagent", ...(input as object) });
      if (d.notice) void toast(client, d.notice);
    },
  };
};
