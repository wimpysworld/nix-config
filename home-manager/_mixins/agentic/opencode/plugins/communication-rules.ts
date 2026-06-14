import { readFileSync } from "node:fs";

const adapterPath = "@tripwireAdapter@";
const adapterContractPath = "@tripwireAdapterContract@";
const scannerPath = "@tripwireScanner@";
const rulesPath = "@tripwireRules@";
const policyPath = "@tripwirePolicy@";
const correctionPromptPath = "@tripwireCorrectionPrompt@";

type ToolInput = {
  tool: string;
  sessionID?: string;
  callID?: string;
};

type ToolOutput = {
  args?: unknown;
};

type SystemTransformOutput = {
  system?: string[];
};

type PluginClient = {
  tui?: {
    showToast?: (input: {
      body: {
        message: string;
        variant?: "default" | "success" | "error" | "loading";
      };
    }) => Promise<unknown>;
  };
  app?: {
    log?: (input: { body: Record<string, unknown> }) => Promise<unknown>;
  };
};

type PluginContext = {
  client?: PluginClient;
};

type AdapterResult = {
  exitCode: number;
  stdout: string;
};

const terminalStates = new Set([
  "pass",
  "block",
  "extraction-failed",
  "correction-request",
]);

const fallbackBlockMessage =
  "Blocked. Revise this prose to follow the Communication Rules.";

const injectedSystemKeys = new Set<string>();

// Tier A facing prose cannot be blocked before the user sees it, so it is never
// re-rolled. A flagged final or subagent message sets a pending re-issue for its
// session; the next system.transform appends the rules to the model silently and
// clears the flag, and the user sees a short toast. One re-issue plus one notice
// per offending turn, with no strike loop.
const pendingReissue = new Set<string>();
const FACING_NOTICE = "Communication Rules breach seen, correcting next reply.";
const REISSUE_LOG_NOTICE = "Communication Rules correction prompt added.";

// Tier B world-output cap on tool.execute.before, split by blast radius. Strikes
// throw, which blocks the call and re-issues the rules to the model; on the
// limit-th strike the gate yields, lets the call run, and toasts a notice. In
// process only, so it resets on restart.
//
// Sub-tier B1 (local: write, edit, patch, bash). Cheap to retract on disk.
// Three-strike-then-yield, keyed on a stable target (sessionID:tool:path) so a
// model that revises the body between retries still walks the cap. Bash and a
// pathless call fall back to sessionID:tool.
const LOCAL_STRIKE_LIMIT = 3;
// Sub-tier B2 (external: gh, gh-api-safe, post-capable MCP tools). Irretractable
// the instant it yields. Five-strike-then-yield, keyed on a stable identity
// (sessionID:tool) so reworded retries of the same logical post draw down one
// budget. Consecutive-with-reset-on-allow: the count accumulates while the same
// external surface keeps failing and resets the moment any call on that key is
// allowed or passes.
const EXTERNAL_STRIKE_LIMIT = 5;
const PRETOOLUSE_YIELD_NOTICE =
  "Communication Rules unmet after retries, output allowed.";
const pretooluseStrikes = new Map<string, number>();

// Baked fallbacks for the post-detection data. fragment.nix is the single
// canonical source, read from policy.json below; these copies apply only when
// the policy file is absent, such as in the fixture harnesses.
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

function loadStringList(
  node: unknown,
  key: string,
  fallback: string[],
): string[] {
  if (isRecord(node)) {
    const value = node[key];
    if (
      Array.isArray(value) &&
      value.every((item) => typeof item === "string")
    ) {
      return value as string[];
    }
  }
  return fallback;
}

function loadPostDetection(): {
  postToolTerms: string[];
  externalTargetKeys: string[];
} {
  let node: unknown;
  try {
    node = JSON.parse(readFileSync(policyPath, "utf-8"));
  } catch {
    return {
      postToolTerms: FALLBACK_POST_TOOL_TERMS,
      externalTargetKeys: FALLBACK_EXTERNAL_TARGET_KEYS,
    };
  }
  for (const key of [
    "communicationRules",
    "detectionPolicy",
    "postDetection",
  ]) {
    node = isRecord(node) ? node[key] : undefined;
  }
  return {
    postToolTerms: loadStringList(
      node,
      "postToolTerms",
      FALLBACK_POST_TOOL_TERMS,
    ),
    externalTargetKeys: loadStringList(
      node,
      "externalTargetKeys",
      FALLBACK_EXTERNAL_TARGET_KEYS,
    ),
  };
}

// Verb fragments that mark an MCP tool as able to post or mutate external state.
const POST_DETECTION = loadPostDetection();
const POST_TOOL_TERMS = POST_DETECTION.postToolTerms;
const EXTERNAL_TARGET_KEYS = POST_DETECTION.externalTargetKeys;

function isPostCapableMcpTool(name: string): boolean {
  if (!name.startsWith("mcp__")) {
    return false;
  }
  const leaf = name.slice(name.lastIndexOf("__") + 2).toLowerCase();
  return POST_TOOL_TERMS.some((term) => leaf.includes(term));
}

function commandText(args: unknown): string | undefined {
  if (!isRecord(args)) {
    return undefined;
  }
  return (
    stringValue(args.command) ??
    stringValue(args.cmd) ??
    stringValue(args.script)
  );
}

// External (B2) surface: the gh CLI tools, or a post-capable MCP tool. A bare
// "gh "/"gh-api-safe " command also counts. Everything else is local (B1).
function isExternalSurface(tool: string, args: unknown): boolean {
  const normalised = tool.toLowerCase();
  if (
    normalised === "gh" ||
    normalised === "gh-api-safe" ||
    normalised === "github"
  ) {
    return true;
  }
  if (isPostCapableMcpTool(tool)) {
    return true;
  }
  const command = commandText(args);
  if (command) {
    const stripped = command.trimStart();
    return stripped.startsWith("gh ") || stripped.startsWith("gh-api-safe ");
  }
  return false;
}

// Operator-visible target for the B2 yield notice: prefer an explicit
// identifier from the args, else fall back to the tool name.
function externalTarget(tool: string, args: unknown): string {
  const label = tool || "post";
  if (isRecord(args)) {
    for (const key of EXTERNAL_TARGET_KEYS) {
      const value = args[key];
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

function decode(value: Uint8Array): string {
  return new TextDecoder().decode(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function adapterPayload(
  input: ToolInput,
  output: ToolOutput,
): Record<string, unknown> {
  return {
    event: "tool.execute.before",
    tool: {
      name: input.tool,
    },
    sessionID: input.sessionID,
    callID: input.callID,
    args: output.args ?? {},
  };
}

function finalDisplayPayload(
  input: { sessionID?: string; messageID?: string; partID?: string },
  output: { text?: string },
): Record<string, unknown> {
  return {
    event: "message.final",
    surface: "final",
    sessionID: input.sessionID,
    messageID: input.messageID,
    partID: input.partID,
    message: {
      content: output.text ?? "",
    },
  };
}

function subagentDisplayPayload(input: {
  sessionID?: string;
  messageID?: string;
  partID?: string;
  text: string;
}): Record<string, unknown> {
  return {
    event: "subagent.final",
    surface: "subagent",
    sessionID: input.sessionID,
    messageID: input.messageID,
    partID: input.partID,
    message: {
      content: input.text,
    },
  };
}

function runAdapter(
  mode: string,
  payload: Record<string, unknown>,
): AdapterResult {
  const process = Bun.spawnSync(["bash", adapterPath, mode], {
    stdin: new Response(JSON.stringify(payload)),
    stdout: "pipe",
    stderr: "pipe",
    env: {
      ...Bun.env,
      TRIPWIRE_ADAPTER_CONTRACT: adapterContractPath,
      TRIPWIRE_CORRECTION_PROMPT: correctionPromptPath,
      TRIPWIRE_SCANNER: scannerPath,
    },
  });

  return {
    exitCode: process.exitCode,
    stdout: decode(process.stdout),
  };
}

function blockMessage(stdout: string): string {
  const lines = stdout.trimEnd().split("\n");
  while (lines.length > 0 && terminalStates.has(lines[lines.length - 1])) {
    lines.pop();
  }

  const message = lines.join("\n").trimEnd();
  return message || fallbackBlockMessage;
}

function stableKey(parts: Array<string | undefined>): string {
  return parts
    .filter(
      (part): part is string => typeof part === "string" && part.length > 0,
    )
    .join(":");
}

function eventProperties(input: unknown): Record<string, unknown> | undefined {
  if (!isRecord(input)) {
    return undefined;
  }
  const event = input.event;
  if (isRecord(event) && isRecord(event.properties)) {
    return event.properties;
  }
  if (isRecord(input.properties)) {
    return input.properties;
  }
  return undefined;
}

function eventType(input: unknown): string {
  if (!isRecord(input)) {
    return "";
  }
  const event = input.event;
  if (isRecord(event) && typeof event.type === "string") {
    return event.type;
  }
  return typeof input.type === "string" ? input.type : "";
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function outputText(output: unknown): string | undefined {
  if (typeof output === "string" && output.length > 0) {
    return output;
  }
  if (isRecord(output)) {
    return (
      stringValue(output.text) ??
      stringValue(output.output) ??
      stringValue(output.content)
    );
  }
  return undefined;
}

function systemTransformKey(input: unknown): string {
  if (!isRecord(input)) {
    return "global";
  }

  const properties = eventProperties(input);
  const session = isRecord(input.session) ? input.session : undefined;
  const path = isRecord(input.path) ? input.path : undefined;
  return (
    stableKey([
      stringValue(input.sessionID),
      stringValue(input.sessionId),
      stringValue(input.session_id),
      stringValue(properties?.sessionID),
      stringValue(properties?.sessionId),
      stringValue(session?.id),
      stringValue(path?.id),
    ]) || "global"
  );
}

function completedSubagentOutput(input: unknown):
  | {
      sessionID?: string;
      messageID?: string;
      partID?: string;
      text: string;
    }
  | undefined {
  if (eventType(input) !== "message.part.updated") {
    return undefined;
  }

  const properties = eventProperties(input);
  const part = isRecord(properties?.part) ? properties.part : undefined;
  if (!part) {
    return undefined;
  }

  const partType = stringValue(part.type);
  const toolName = stringValue(part.tool) ?? stringValue(part.name);
  if (
    partType !== "tool" ||
    !["task", "agent", "subagent"].includes(toolName ?? "")
  ) {
    return undefined;
  }

  const state = isRecord(part.state) ? part.state : undefined;
  if (!state || state.status !== "completed") {
    return undefined;
  }

  const text = outputText(state.output);
  if (!text) {
    return undefined;
  }

  return {
    sessionID:
      stringValue(part.sessionID) ?? stringValue(properties?.sessionID),
    messageID:
      stringValue(part.messageID) ?? stringValue(properties?.messageID),
    partID: stringValue(part.id) ?? stringValue(properties?.partID),
    text,
  };
}

async function logNotice(
  client: PluginClient | undefined,
  message: string,
): Promise<void> {
  try {
    await client?.app?.log?.({
      body: {
        service: "communication-rules",
        level: "warn",
        message,
      },
    });
  } catch {
    return;
  }
}

async function toastNotice(
  client: PluginClient | undefined,
  message: string,
): Promise<void> {
  // Surface a short notice to the user via a toast, with the structured log as a
  // fallback. The TUI is absent in web, headless, serve, and attach modes, so
  // guard the call and swallow errors.
  try {
    await client?.tui?.showToast?.({
      body: {
        message,
        variant: "error",
      },
    });
  } catch {
    // Fall through to the debug log even if the toast cannot be shown.
  }

  await logNotice(client, message);
}

function appendFacingNotice(
  output: { text?: string } | undefined,
  message: string,
): void {
  if (
    !output ||
    typeof output.text !== "string" ||
    output.text.includes(message)
  ) {
    return;
  }

  output.text = `${output.text.trimEnd()}\n\n${message}`;
}

// The STABLE B1 target the local strike counter keys on: the file path for
// write/edit/patch tools. Returns undefined for bash or a pathless call, so the
// key falls back to sessionID:tool. Keying on the path rather than the body
// means a model that revises the content between retries still walks the cap.
function localTarget(tool: string, args: unknown): string | undefined {
  const normalised = tool.toLowerCase().replace(/[-.]/g, "_");
  const isFileTool =
    [
      "write",
      "edit",
      "multiedit",
      "multi_edit",
      "patch",
      "apply_patch",
      "str_replace",
    ].includes(normalised) ||
    normalised.endsWith("_write") ||
    normalised.endsWith("_edit") ||
    normalised.endsWith("_patch");
  if (!isFileTool || !isRecord(args)) {
    return undefined;
  }
  for (const key of ["path", "file_path", "filePath", "filename", "file"]) {
    const value = args[key];
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }
  return undefined;
}

// B1 (local) keys on a stable target (sessionID:tool:path), so a model that
// revises the body between retries still accumulates strikes against the same
// path and yields on the 3rd, instead of minting a fresh strike-1 key per
// revision. Bash and a pathless call fall back to sessionID:tool, a
// consecutive-block counter that resets on a clean pass; the trade-off is that
// two unrelated bash commands with no pass between them share one budget, which
// is rare and acceptable. B2 (external) keys on a stable identity
// (external:sessionID:tool) so reworded posts share one budget.
function pretooluseStrikeKey(input: ToolInput, output: ToolOutput): string {
  const base = stableKey([input.sessionID, input.tool]);
  if (isExternalSurface(input.tool, output.args)) {
    return "external:" + base;
  }
  const target = localTarget(input.tool, output.args);
  return target ? base + ":" + target : base;
}

// Tier A: scan a displayed final or subagent message. On a breach, flag a
// pending re-issue for the session and toast the user once. Never re-roll.
function maybeFlagReissue(
  client: PluginClient | undefined,
  payload: Record<string, unknown>,
  sessionID: string | undefined,
  displayOutput?: { text?: string },
): void {
  let result: AdapterResult;
  try {
    result = runAdapter("post-display", payload);
  } catch {
    return;
  }

  if (result.exitCode === 0) {
    return;
  }

  const key = sessionID ?? "global";
  pendingReissue.add(key);
  appendFacingNotice(displayOutput, FACING_NOTICE);
  void toastNotice(client, FACING_NOTICE);
}

async function injectRules(
  client: PluginClient | undefined,
  input: unknown,
  output: SystemTransformOutput,
): Promise<void> {
  const key = systemTransformKey(input);
  let rules: string;
  let correctionPrompt: string;
  try {
    rules = (await Bun.file(rulesPath).text()).trimEnd();
    correctionPrompt = (await Bun.file(correctionPromptPath).text()).trimEnd();
  } catch {
    return;
  }
  if (!rules || !correctionPrompt) {
    return;
  }

  output.system ??= [];

  // Base rules: inject once per session so the model always carries them.
  if (!injectedSystemKeys.has(key)) {
    const section = `Communication Rules:\n${rules}`;
    if (!output.system.includes(section)) {
      output.system.push(section);
    }
    injectedSystemKeys.add(key);
  }

  // Silent Tier A re-issue: while a breach is pending for this session, append a
  // corrective re-issue (model-only) and clear the flag. This corrects the next
  // turn without re-rolling the message the user already saw.
  if (pendingReissue.has(key)) {
    pendingReissue.delete(key);
    if (!output.system.includes(correctionPrompt)) {
      output.system.push(correctionPrompt);
    }
    await logNotice(client, REISSUE_LOG_NOTICE);
  }
}

export const CommunicationRules = async (context: PluginContext = {}) => {
  const client = context.client;

  return {
    "experimental.chat.system.transform": async (
      input: unknown,
      output: SystemTransformOutput,
    ) => {
      await injectRules(client, input, output);
    },
    "tool.execute.before": async (input: ToolInput, output: ToolOutput) => {
      const key = pretooluseStrikeKey(input, output);

      let result: AdapterResult;
      try {
        result = runAdapter(
          "tool-execute-before",
          adapterPayload(input, output),
        );
      } catch {
        // Fail closed under the strike cap rather than blocking forever.
        result = { exitCode: 1, stdout: "" };
      }

      if (result.exitCode === 0) {
        pretooluseStrikes.delete(key);
        return;
      }

      const external = isExternalSurface(input.tool, output.args);
      const limit = external ? EXTERNAL_STRIKE_LIMIT : LOCAL_STRIKE_LIMIT;

      const strikes = (pretooluseStrikes.get(key) ?? 0) + 1;
      pretooluseStrikes.set(key, strikes);

      if (strikes >= limit) {
        // Best-effort yield: after the denials let the call run, reset the
        // counter, and toast a notice instead of blocking forever. B2 externals
        // name the tool and target so a breach can be retracted fast; the error
        // variant keeps the toast visible.
        pretooluseStrikes.delete(key);
        const notice = external
          ? `Rules breach posted: ${externalTarget(input.tool, output.args)}`
          : PRETOOLUSE_YIELD_NOTICE;
        void toastNotice(client, notice);
        return;
      }

      // Before the limit: throw to block the call. The thrown message re-issues
      // the rules to the model so it retries with compliant content.
      throw new Error(blockMessage(result.stdout) || fallbackBlockMessage);
    },
    "experimental.text.complete": async (
      input: { sessionID?: string; messageID?: string; partID?: string },
      output: { text?: string },
    ) => {
      maybeFlagReissue(
        client,
        finalDisplayPayload(input, output),
        input.sessionID,
        output,
      );
    },
    event: async (input: unknown) => {
      const subagentOutput = completedSubagentOutput(input);
      if (!subagentOutput) {
        return;
      }

      maybeFlagReissue(
        client,
        subagentDisplayPayload(subagentOutput),
        subagentOutput.sessionID,
      );
    },
  };
};
