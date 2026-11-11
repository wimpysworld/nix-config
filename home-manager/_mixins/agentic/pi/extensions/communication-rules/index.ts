import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AgentMessage } from "@earendil-works/pi-agent-core";

const configPath = path.join(os.homedir(), ".pi/agent/extensions/communication-rules/config.json");

interface Config { adapterPath: string }
type Level = "info" | "warning" | "error";
interface Decision { decision: "pass" | "advisory"; notice: string; level: Level }

function loadConfig(): Config | undefined {
  try {
    const c = JSON.parse(fs.readFileSync(configPath, "utf-8")) as Partial<Config>;
    if (typeof c.adapterPath === "string" && c.adapterPath) return c as Config;
  } catch { /* fall through */ }
  return undefined;
}
function sessionId(ctx: ExtensionContext | undefined): string {
  try { return ctx?.sessionManager?.getSessionId?.() ?? ""; } catch { return ""; }
}
function decide(config: Config, event: string, payload: unknown, ctx?: ExtensionContext): Decision {
  const base = (payload && typeof payload === "object") ? payload as Record<string, unknown> : {};
  const merged = { ...base, session_id: sessionId(ctx) || base.session_id };
  const r = spawnSync(config.adapterPath, ["pi", event], {
    encoding: "utf-8", input: JSON.stringify(merged), timeout: 2000, maxBuffer: 64 * 1024,
  });
  if (!r.error && r.status === 0) {
    const decision = JSON.parse(r.stdout);
    if (decision && ["pass", "advisory"].includes(decision.decision)
      && (decision.notice === undefined || typeof decision.notice === "string")) return decision;
  }
  throw new Error("Communication Rules checker unavailable.");
}
function message(content: string): AgentMessage {
  return { role: "custom", customType: "communication-rules", content, display: false, timestamp: Date.now() } as unknown as AgentMessage;
}
export default function registerCommunicationRules(pi: ExtensionAPI): void {
  const config = loadConfig();
  if (!config) return;
  let turn = 0;
  const noticed = new Set<string>();
  const diagnosed = new Set<string>();
  const diagnose = (ctx: ExtensionContext) => {
    const id = sessionId(ctx);
    if (diagnosed.has(id)) return;
    diagnosed.add(id);
    console.error("Communication Rules: checker unavailable. The operation is unchanged.");
  };
  const notify = (ctx: ExtensionContext, decision: Decision) => {
    const id = sessionId(ctx);
    if (!decision.notice || noticed.has(id)) return;
    noticed.add(id);
    if (ctx.hasUI) ctx.ui.notify(decision.notice.slice(0, 320), "warning");
  };
  pi.on("before_agent_start", (_event, ctx) => {
    try {
      noticed.delete(sessionId(ctx));
      diagnosed.delete(sessionId(ctx));
      decide(config, "turn-start", { turn_id: `${Date.now()}-${++turn}` }, ctx);
    } catch { diagnose(ctx); }
  });
  pi.on("context", (event, ctx) => {
    try {
      const d = decide(config, "context", {}, ctx);
      if (d.notice && Array.isArray(event.messages)) {
        noticed.add(sessionId(ctx));
        return { messages: [...event.messages, message(d.notice.slice(0, 320))] };
      }
    } catch { diagnose(ctx); }
    return undefined;
  });
  pi.on("tool_call", (event, ctx) => {
    try { notify(ctx, decide(config, "tool_call", event, ctx)); } catch { diagnose(ctx); }
    return undefined;
  });
  pi.on("message_end", (event, ctx) => {
    try {
      if (event.message?.role === "assistant") notify(ctx, decide(config, "message_end", event, ctx));
    } catch { diagnose(ctx); }
    return undefined;
  });
}
