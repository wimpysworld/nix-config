import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { TextContent } from "@mariozechner/pi-ai";

// Thin shim. All policy lives in the Python core; each handler spawns
// `core pi <event>` and maps the decision to Pi's return shape. The context
// messages and notify writes are the one named exception to "zero logic in TS":
// runtime glue applying the core's Tier A flags, not policy.
const FALLBACK_BLOCK = "Blocked. Revise this prose to follow the Communication Rules.";
const configPath = path.join(os.homedir(), ".pi/agent/extensions/communication-rules/config.json");

interface Config { adapterPath: string; rulesPath: string; correctionPromptPath: string }
type Level = "info" | "warning" | "error";
interface Decision { decision: string; notice: string; level: Level; inject_base_rules: boolean; append_correction: boolean }

function readText(file: string): string {
  try { return fs.readFileSync(file, "utf-8").trim(); } catch { return ""; }
}
function loadConfig(): Config | undefined {
  try {
    const c = JSON.parse(fs.readFileSync(configPath, "utf-8")) as Partial<Config>;
    if (c.adapterPath && c.rulesPath && c.correctionPromptPath) return c as Config;
  } catch { /* fall through */ }
  return undefined;
}
// Read Pi's per-session id defensively. Pi's real `tool_call` event carries no
// session, so the core would otherwise share one strike namespace across all
// sessions. Threading this id gives each session its own counter.
function sessionId(ctx: ExtensionContext | undefined): string {
  try { return ctx?.sessionManager?.getSessionId?.() ?? ""; } catch { return ""; }
}
// Spawn the core and parse its one-line decision; a failed spawn fails closed.
// The session id is merged at the top level of the payload, where the core
// reads it, preferring Pi's live id and falling back to any id already present.
function decide(config: Config, event: string, payload: unknown, ctx?: ExtensionContext): Decision {
  const base = (payload && typeof payload === "object") ? payload as Record<string, unknown> : {};
  const merged = { ...base, session_id: sessionId(ctx) || base.session_id };
  const r = spawnSync(config.adapterPath, ["pi", event], { encoding: "utf-8", input: JSON.stringify(merged) });
  try { if (!r.error && r.status === 0) return JSON.parse((r.stdout ?? "").trim()) as Decision; } catch { /* fall through */ }
  return { decision: "block", notice: "", level: "error", inject_base_rules: false, append_correction: false };
}
// Model-facing block reason: the core's rules block message (content, cached).
let blockReason: string | undefined;
function blockMessage(config: Config): string {
  if (blockReason === undefined) {
    const r = spawnSync(config.adapterPath, ["block-message"], { encoding: "utf-8" });
    blockReason = !r.error && r.status === 0 ? (r.stdout ?? "").trim() : "";
  }
  return blockReason || FALLBACK_BLOCK;
}
function message(content: string): AgentMessage {
  return { role: "custom", customType: "communication-rules", content, display: false, timestamp: Date.now() } as unknown as AgentMessage;
}
function notify(ctx: ExtensionContext, text: string, level: Level): void {
  if (text && ctx.hasUI) ctx.ui.notify(text, level);
}

export default function registerCommunicationRules(pi: ExtensionAPI): void {
  const config = loadConfig();
  if (!config) return;
  pi.on("context", (event, ctx) => {
    const d = decide(config, "context", event, ctx);
    const additions: AgentMessage[] = [];
    if (d.inject_base_rules) additions.push(message(`Communication Rules:\n${readText(config.rulesPath)}`));
    if (d.append_correction) additions.push(message(readText(config.correctionPromptPath)));
    const messages = Array.isArray(event.messages) ? event.messages : [];
    return additions.length > 0 ? { messages: [...messages, ...additions] } : undefined;
  });
  pi.on("tool_call", (event, ctx) => {
    const d = decide(config, "tool_call", event, ctx);
    // `yield` (B2 cap) and `allow-revise` (B1 strike 2+) are non-blocking allows: notify, let the tool run.
    if (d.decision === "yield" || d.decision === "allow-revise") { notify(ctx, d.notice, d.level); return undefined; }
    // A clean pass lets the tool run.
    if (d.decision === "pass") return undefined;
    // A middle B2 block carries the short nudge in `d.notice`; the first and
    // penultimate blocks carry an empty notice and re-issue the full cached
    // rules. So prefer the notice when set, fall back to the full message. Any
    // unrecognised decision fails closed on this gating surface: block with the
    // full cached rules (default-deny), matching Tier B fail-closed.
    return { block: true, reason: d.notice || blockMessage(config) };
  });
  pi.on("message_end", (event, ctx) => {
    const d = decide(config, "message_end", event, ctx);
    notify(ctx, d.notice, d.level);
    return undefined;
  });
  pi.on("tool_result", (event, ctx) => {
    if (decide(config, "tool_result", event, ctx).decision !== "block") return undefined;
    const details = event && typeof event === "object" ? (event as { details?: unknown }).details : undefined;
    return { content: [{ type: "text", text: blockMessage(config) } as TextContent], details, isError: true };
  });
}
