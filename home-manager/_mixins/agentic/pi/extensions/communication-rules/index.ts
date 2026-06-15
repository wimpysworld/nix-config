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
// Spawn the core and parse its one-line decision; a failed spawn fails closed.
function decide(config: Config, event: string, payload: unknown): Decision {
  const r = spawnSync(config.adapterPath, ["pi", event], { encoding: "utf-8", input: JSON.stringify(payload ?? {}) });
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
  pi.on("context", (event) => {
    const d = decide(config, "context", event);
    const additions: AgentMessage[] = [];
    if (d.inject_base_rules) additions.push(message(`Communication Rules:\n${readText(config.rulesPath)}`));
    if (d.append_correction) additions.push(message(readText(config.correctionPromptPath)));
    const messages = Array.isArray(event.messages) ? event.messages : [];
    return additions.length > 0 ? { messages: [...messages, ...additions] } : undefined;
  });
  pi.on("tool_call", (event, ctx) => {
    const d = decide(config, "tool_call", event);
    if (d.decision === "yield") notify(ctx, d.notice, d.level);
    return d.decision === "block" ? { block: true, reason: blockMessage(config) } : undefined;
  });
  pi.on("message_end", (event, ctx) => {
    const d = decide(config, "message_end", event);
    notify(ctx, d.notice, d.level);
    return undefined;
  });
  pi.on("tool_result", (event) => {
    if (decide(config, "tool_result", event).decision !== "block") return undefined;
    const details = event && typeof event === "object" ? (event as { details?: unknown }).details : undefined;
    return { content: [{ type: "text", text: blockMessage(config) } as TextContent], details, isError: true };
  });
}
