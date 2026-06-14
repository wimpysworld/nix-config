import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { TextContent } from "@mariozechner/pi-ai";

interface ExtensionConfig {
  adapterPath?: unknown;
  rulesPath?: unknown;
  correctionPromptPath?: unknown;
  policyPath?: unknown;
}

interface AdapterResult {
  blocked: boolean;
  text: string;
}

const CUSTOM_TYPE = "communication-rules";
const REISSUE_TYPE = "communication-rules-reissue";
const FALLBACK_BLOCK =
  "Blocked. Revise this prose to follow the Communication Rules.";
const FACING_NOTICE =
  "Communication Rules breach seen, correcting next reply.";
const PRETOOLUSE_YIELD_NOTICE =
  "Communication Rules unmet after retries, output allowed.";
// Sub-tier B1 (local: write, edit, patch, bash). Cheap to retract on disk.
// Three-strike-then-yield, keyed on a stable target (session:tool:path) so a
// model that revises the body between retries still walks the cap. Bash and a
// pathless call fall back to session:tool.
const LOCAL_STRIKE_LIMIT = 3;
// Sub-tier B2 (external: gh, gh-api-safe, post-capable MCP tools). Irretractable
// the instant it yields, so a wider budget before the irreversible yield.
const EXTERNAL_STRIKE_LIMIT = 5;

// Baked fallbacks for the post-detection data. fragment.nix is the single
// canonical source, read from policy.json via loadPostDetection; these copies
// apply only when the policy file is absent, such as in the fixture harnesses.
const FALLBACK_POST_TOOL_TERMS = [
  "comment",
  "create",
  "edit",
  "post",
  "publish",
  "reply",
  "review",
  "send",
  "submit",
  "update",
  "write",
];

const FALLBACK_EXTERNAL_TARGET_KEYS = [
  "url",
  "pull_number",
  "issue_number",
  "number",
  "pullRequestId",
  "issueId",
  "discussionId",
  "id",
  "path",
  "repo",
  "repository",
  "owner",
];

// Verb fragments that mark an MCP tool as able to post or mutate external state.
// Populated from policy.json by loadPostDetection, falling back to the baked
// copies above.
let POST_TOOL_TERMS = FALLBACK_POST_TOOL_TERMS;
let EXTERNAL_TARGET_KEYS = FALLBACK_EXTERNAL_TARGET_KEYS;

function loadStringList(node: unknown, key: string, fallback: string[]): string[] {
  if (isRecord(node)) {
    const value = node[key];
    if (Array.isArray(value) && value.every((item) => typeof item === "string")) {
      return value as string[];
    }
  }
  return fallback;
}

function loadPostDetection(policyPath: string | undefined): void {
  if (!policyPath) return;
  let node: unknown;
  try {
    node = JSON.parse(fs.readFileSync(policyPath, "utf-8"));
  } catch {
    return;
  }
  for (const key of ["communicationRules", "detectionPolicy", "postDetection"]) {
    node = isRecord(node) ? node[key] : undefined;
  }
  POST_TOOL_TERMS = loadStringList(node, "postToolTerms", FALLBACK_POST_TOOL_TERMS);
  EXTERNAL_TARGET_KEYS = loadStringList(node, "externalTargetKeys", FALLBACK_EXTERNAL_TARGET_KEYS);
}

const configPath = path.join(
  os.homedir(),
  ".pi/agent/extensions/communication-rules/config.json",
);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function eventToolName(event: unknown): string {
  const record = isRecord(event) ? event : {};
  return typeof record.toolName === "string"
    ? record.toolName
    : typeof record.tool_name === "string"
      ? record.tool_name
      : typeof record.name === "string"
        ? record.name
        : typeof record.tool === "string"
          ? record.tool
          : "";
}

function eventToolInput(event: unknown): unknown {
  const record = isRecord(event) ? event : {};
  return record.input ?? record.args ?? {};
}

function isPostCapableMcpTool(name: string): boolean {
  if (!name.startsWith("mcp__")) {
    return false;
  }
  const leaf = name.slice(name.lastIndexOf("__") + 2).toLowerCase();
  return POST_TOOL_TERMS.some((term) => leaf.includes(term));
}

// External (B2) surface: the gh CLI tools, or a post-capable MCP tool. A bare
// "gh "/"gh-api-safe " command also counts. Everything else is local (B1).
function isExternalSurface(event: unknown): boolean {
  const name = eventToolName(event).toLowerCase();
  if (name === "gh" || name === "gh-api-safe" || name === "github") {
    return true;
  }
  if (isPostCapableMcpTool(eventToolName(event))) {
    return true;
  }
  const input = eventToolInput(event);
  if (isRecord(input)) {
    const command = input.command ?? input.cmd ?? input.script;
    if (typeof command === "string") {
      const stripped = command.trimStart();
      return stripped.startsWith("gh ") || stripped.startsWith("gh-api-safe ");
    }
  }
  return false;
}

// Operator-visible target for the B2 yield notice: prefer an explicit identifier
// from the input, else fall back to the tool name.
function externalTarget(event: unknown): string {
  const label = eventToolName(event) || "post";
  const input = eventToolInput(event);
  if (isRecord(input)) {
    for (const key of EXTERNAL_TARGET_KEYS) {
      const value = input[key];
      if (typeof value === "string" && value.length > 0) {
        return `${label} ${value}`;
      }
      if (typeof value === "number") {
        return `${label} ${value}`;
      }
    }
  }
  return label;
}

// The STABLE B1 target the local strike counter keys on: the file path for
// write/edit/patch tools. Returns undefined for bash or a pathless call, so the
// key falls back to session:tool. Keying on the path rather than the body means
// a model that revises the content between retries still walks the cap.
function localTarget(event: unknown): string | undefined {
  const normalised = eventToolName(event).toLowerCase().replace(/[-.]/g, "_");
  const isFileTool =
    ["write", "edit", "multiedit", "multi_edit", "patch", "apply_patch", "applypatch", "str_replace"].includes(
      normalised,
    ) ||
    normalised.endsWith("_write") ||
    normalised.endsWith("_edit") ||
    normalised.endsWith("_patch");
  if (!isFileTool) {
    return undefined;
  }
  const input = eventToolInput(event);
  if (!isRecord(input)) {
    return undefined;
  }
  for (const key of ["path", "file_path", "filePath", "filename", "file"]) {
    const value = input[key];
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }
  return undefined;
}

// The Tier B strike key. B1 (local) keys on a stable target (session:tool:path),
// so a model that revises the body between retries still accumulates strikes
// against the same path and yields on the 3rd, instead of minting a fresh
// strike-1 key per revision. Bash and a pathless call fall back to session:tool,
// a consecutive-block counter that resets on a clean pass; the trade-off is that
// two unrelated bash commands with no pass between them share one budget, which
// is rare and acceptable. B2 (external) keys on a stable identity (session +
// tool), so reworded posts draw down one budget. Consecutive-with-reset-on-allow:
// the count accumulates while the same surface keeps failing and resets the
// moment any call on that key is allowed or passes.
function toolCallKey(sessionKeyValue: string, event: unknown): string {
  const name = eventToolName(event);
  if (isExternalSurface(event)) {
    return `external:${sessionKeyValue}:${name}`;
  }
  const target = localTarget(event);
  return target ? `${sessionKeyValue}:${name}:${target}` : `${sessionKeyValue}:${name}`;
}

function loadConfig():
  | {
      adapterPath: string;
      rulesPath: string;
      correctionPromptPath: string;
      policyPath?: string;
    }
  | undefined {
  try {
    const parsed = JSON.parse(fs.readFileSync(configPath, "utf-8")) as ExtensionConfig;
    if (
      typeof parsed.adapterPath === "string" &&
      parsed.adapterPath.length > 0 &&
      typeof parsed.rulesPath === "string" &&
      parsed.rulesPath.length > 0 &&
      typeof parsed.correctionPromptPath === "string" &&
      parsed.correctionPromptPath.length > 0
    ) {
      return {
        adapterPath: parsed.adapterPath,
        rulesPath: parsed.rulesPath,
        correctionPromptPath: parsed.correctionPromptPath,
        policyPath:
          typeof parsed.policyPath === "string" && parsed.policyPath.length > 0
            ? parsed.policyPath
            : undefined,
      };
    }
  } catch {
    return undefined;
  }

  return undefined;
}

function loadRules(config: { rulesPath: string }): string | undefined {
  try {
    const rules = fs.readFileSync(config.rulesPath, "utf-8").trim();
    return rules.length > 0 ? rules : undefined;
  } catch {
    return undefined;
  }
}

function loadCorrectionPrompt(config: { correctionPromptPath: string }): string | undefined {
  try {
    const prompt = fs.readFileSync(config.correctionPromptPath, "utf-8").trim();
    return prompt.length > 0 ? prompt : undefined;
  } catch {
    return undefined;
  }
}

function serialiseEvent(event: unknown): string {
  return JSON.stringify(event ?? {});
}

function cleanAdapterText(output: string): string {
  const lines = output
    .replace(/\r\n/g, "\n")
    .split("\n")
    .map((line) => line.trimEnd());

  while (lines.length > 0 && lines[lines.length - 1] === "") {
    lines.pop();
  }

  if (lines[lines.length - 1] === "pass" || lines[lines.length - 1] === "block") {
    lines.pop();
  }

  return lines.join("\n").trim();
}

function textBlock(text: string): TextContent {
  return {
    type: "text",
    text,
  };
}

// An intermediate tool-use turn is not the final prose, so it must not be
// scanned or corrected. Pi marks these turns with stopReason "toolUse". The
// adapter already returns pass for them, but guard here too as defence in
// depth so a turn is never scanned before the model has finished speaking.
function isIntermediateToolUse(event: unknown): boolean {
  if (!isRecord(event) || !isRecord(event.message)) return false;
  return event.message.stopReason === "toolUse";
}

function sessionKey(ctx: ExtensionContext): string {
  try {
    const sessionId = ctx.sessionManager.getSessionId();
    if (sessionId) return sessionId;
  } catch {
    // Fall through to the session file and cwd fallbacks.
  }

  try {
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (sessionFile) return sessionFile;
  } catch {
    // Fall through to cwd.
  }

  return ctx.cwd;
}

function runAdapter(
  config: { adapterPath: string },
  eventName: string,
  event: unknown,
): AdapterResult {
  const result = spawnSync(config.adapterPath, [eventName], {
    encoding: "utf-8",
    input: serialiseEvent(event),
  });

  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  if (result.error || result.status !== 0) {
    return {
      blocked: true,
      text: cleanAdapterText(output) || FALLBACK_BLOCK,
    };
  }

  return {
    blocked: false,
    text: cleanAdapterText(output),
  };
}

function hasInjectedRules(messages: unknown): boolean {
  if (!Array.isArray(messages)) return false;
  return messages.some(
    (message) =>
      isRecord(message) &&
      message.role === "custom" &&
      message.customType === CUSTOM_TYPE,
  );
}

function rulesMessage(rules: string): AgentMessage {
  return {
    role: "custom",
    customType: CUSTOM_TYPE,
    content: `Communication Rules:\n${rules}`,
    display: false,
    timestamp: Date.now(),
  } as unknown as AgentMessage;
}

function reissueMessage(correctionPrompt: string): AgentMessage {
  return {
    role: "custom",
    customType: REISSUE_TYPE,
    content: correctionPrompt,
    display: false,
    timestamp: Date.now(),
  } as unknown as AgentMessage;
}

function notify(
  ctx: ExtensionContext,
  message: string,
  type: "info" | "warning" | "error" = "info",
): void {
  if (!message || !ctx.hasUI) return;
  ctx.ui.notify(message, type);
}

export default function registerCommunicationRules(pi: ExtensionAPI): void {
  const config = loadConfig();
  if (!config) return;
  loadPostDetection(config.policyPath);
  const pretooluseStrikes = new Map<string, number>();
  // Tier A facing prose cannot be blocked before the user sees it, so it is
  // never re-rolled. A flagged final message marks its session pending; the next
  // context build appends the rules re-issue (model-only) and clears the flag.
  const pendingReissue = new Set<string>();

  pi.on("context", (event, ctx) => {
    const rules = loadRules(config);
    const correctionPrompt = loadCorrectionPrompt(config);
    if (!rules || !correctionPrompt) return undefined;

    const messages = Array.isArray(event.messages) ? event.messages : [];
    const additions: AgentMessage[] = [];

    if (!hasInjectedRules(event.messages)) {
      additions.push(rulesMessage(rules));
    }

    // Silent Tier A re-issue: while a breach is pending for this session, append
    // a corrective re-issue (display:false) and clear the flag, so the next turn
    // is corrected without re-rolling the message the user already saw.
    const key = sessionKey(ctx);
    if (pendingReissue.has(key)) {
      pendingReissue.delete(key);
      additions.push(reissueMessage(correctionPrompt));
    }

    if (additions.length === 0) return undefined;
    return {
      messages: [...messages, ...additions],
    };
  });

  pi.on("tool_call", (event, ctx) => {
    const result = runAdapter(config, "tool_call", event);
    const key = toolCallKey(sessionKey(ctx), event);

    if (!result.blocked) {
      pretooluseStrikes.delete(key);
      return undefined;
    }

    const external = isExternalSurface(event);
    const limit = external ? EXTERNAL_STRIKE_LIMIT : LOCAL_STRIKE_LIMIT;

    const strikes = (pretooluseStrikes.get(key) ?? 0) + 1;
    pretooluseStrikes.set(key, strikes);

    if (strikes >= limit) {
      // Best-effort yield: after the denials let the call run, reset the
      // counter, and show a notice instead of blocking forever. B2 externals
      // name the tool and target so a breach can be retracted fast; the error
      // level keeps the notice visible.
      pretooluseStrikes.delete(key);
      if (external) {
        notify(ctx, `Rules breach posted: ${externalTarget(event)}`, "error");
      } else {
        notify(ctx, PRETOOLUSE_YIELD_NOTICE, "warning");
      }
      return undefined;
    }

    // Before the limit: block and re-issue the rules to the model via reason.
    return {
      block: true,
      reason: result.text || FALLBACK_BLOCK,
    };
  });

  pi.on("message_end", (event, ctx) => {
    // Skip intermediate tool-use turns: they are not final prose to correct.
    if (isIntermediateToolUse(event)) return undefined;

    // Tier A facing prose: the adapter never blocks here. A breach prints the
    // "reissue" sentinel; a clean message prints nothing. Never re-roll: flag a
    // pending re-issue for the model's next turn and show the user one notice.
    const result = runAdapter(config, "message_end", event);
    if (result.text === "reissue") {
      pendingReissue.add(sessionKey(ctx));
      notify(ctx, FACING_NOTICE, "warning");
    }
    return undefined;
  });

  pi.on("tool_result", (event) => {
    const result = runAdapter(config, "tool_result", event);
    if (!result.blocked) return undefined;

    return {
      content: [textBlock(result.text || FALLBACK_BLOCK)],
      details: isRecord(event) ? event.details : undefined,
      isError: true,
    };
  });
}
