import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { pathToFileURL } from "node:url";

type Handler = (event: unknown, ctx: Record<string, unknown>) => unknown;

const fixtureDir = __dirname;
const rootDir = path.resolve(fixtureDir, "../..");
const adapter = path.join(rootDir, "adapters/pi.sh");
const scanner = path.join(rootDir, "scanner.py");
const extension = path.resolve(
  fixtureDir,
  "../../../../pi/extensions/communication-rules/index.ts",
);
const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "pi-tripwire-fixtures-"));
const configDir = path.join(tempHome, ".pi/agent/extensions/communication-rules");
const wrapper = path.join(tempHome, "pi-adapter");
const scannerWrapper = path.join(tempHome, "agent-communication-check");
const rulesPath = path.join(tempHome, "rules.md");

function fail(message: string): never {
  throw new Error(`pi extension fixture failed: ${message}`);
}

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function readFixture(name: string): unknown {
  return JSON.parse(fs.readFileSync(path.join(fixtureDir, name), "utf-8"));
}

function textFromResult(result: unknown): string {
  if (
    typeof result === "object" &&
    result !== null &&
    "message" in result &&
    typeof result.message === "object" &&
    result.message !== null &&
    "content" in result.message &&
    Array.isArray(result.message.content)
  ) {
    const block = result.message.content[0];
    if (
      typeof block === "object" &&
      block !== null &&
      "text" in block &&
      typeof block.text === "string"
    ) {
      return block.text;
    }
  }

  if (
    typeof result === "object" &&
    result !== null &&
    "content" in result &&
    Array.isArray(result.content)
  ) {
    const block = result.content[0];
    if (
      typeof block === "object" &&
      block !== null &&
      "text" in block &&
      typeof block.text === "string"
    ) {
      return block.text;
    }
  }

  return "";
}

fs.mkdirSync(configDir, { recursive: true });
const canonicalRules = fs.readFileSync(path.join(rootDir, "communication-rules.md"), "utf-8").trim();
fs.writeFileSync(rulesPath, `${canonicalRules}\n`, "utf-8");
fs.writeFileSync(
  scannerWrapper,
  [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    `exec python3 ${shellQuote(scanner)} --rules ${shellQuote(rulesPath)} "$@"`,
    "",
  ].join("\n"),
  "utf-8",
);
fs.chmodSync(scannerWrapper, 0o755);
fs.writeFileSync(
  wrapper,
  [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    `export TRIPWIRE_SCANNER=${shellQuote(scannerWrapper)}`,
    `exec bash ${shellQuote(adapter)} "$@"`,
    "",
  ].join("\n"),
  "utf-8",
);
fs.chmodSync(wrapper, 0o755);
// Mirror the shared post-detection lists so the extension exercises its
// policy.json load path. The values match fragment.nix's canonical source.
const policyPath = path.join(tempHome, "policy.json");
fs.writeFileSync(
  policyPath,
  JSON.stringify({
    communicationRules: {
      detectionPolicy: {
        postDetection: {
          postToolTerms: [
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
          ],
          externalTargetKeys: [
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
          ],
        },
      },
    },
  }),
  "utf-8",
);
fs.writeFileSync(
  path.join(configDir, "config.json"),
  JSON.stringify({ adapterPath: wrapper, rulesPath, policyPath }),
  "utf-8",
);

process.env.HOME = tempHome;

async function main(): Promise<void> {
  const handlers = new Map<string, Handler>();
  const notifications: string[] = [];
  const sentMessages: string[] = [];
  const register = (
    await import(pathToFileURL(extension).href)
  ) as { default: (pi: Record<string, unknown>) => void };

  register.default({
    on(event: string, handler: Handler): void {
      handlers.set(event, handler);
    },
    sendUserMessage(content: unknown): void {
      sentMessages.push(typeof content === "string" ? content : JSON.stringify(content));
    },
  });

  function handler(name: string): Handler {
    const registered = handlers.get(name);
    if (!registered) fail(`${name} handler was not registered`);
    return registered;
  }

  function context(sessionId = "fixture"): Record<string, unknown> {
    return {
      hasUI: true,
      cwd: process.cwd(),
      ui: {
        notify(message: string, type: string): void {
          notifications.push(`${type}:${message}`);
        },
      },
      sessionManager: {
        getSessionId(): string {
          return sessionId;
        },
        getSessionFile(): string {
          return `${sessionId}.jsonl`;
        },
      },
    };
  }

  const cleanFinal = handler("message_end")(
    readFixture("message-end-final-clean.json"),
    context("clean"),
  );
  if (cleanFinal !== undefined) fail("clean message_end should not be replaced");

  // Defence in depth: an intermediate tool-use turn (stopReason "toolUse") must
  // be skipped by the extension guard, never scanned or replaced.
  const toolUseTurn = handler("message_end")(
    readFixture("message-end-tool-use-pass.json"),
    context("tool-use"),
  );
  if (toolUseTurn !== undefined) fail("intermediate tool-use turn should not be scanned");
  if (notifications.length !== 0) fail("intermediate tool-use turn should not notify");

  const disclosureFinal = handler("message_end")(
    {
      message: {
        role: "assistant",
        content: [{ type: "text", text: canonicalRules }],
      },
    },
    context("disclosure"),
  );
  if (disclosureFinal !== undefined) fail("policy disclosure should not be replaced");

  // The leak sentinel is assembled at runtime so this source file stays clean.
  const leak = ["DEL", "VE"].join("");

  // Tier A facing prose: a blocked final is never re-rolled. The extension shows
  // one user notice and never queues a follow-up user message.
  const facingCtx = context("facing");
  const blockedFinal = handler("message_end")(
    readFixture("message-end-final-blocked.json"),
    facingCtx,
  );
  if (blockedFinal !== undefined) {
    fail("blocked message_end must not replace or re-roll the response");
  }
  if (sentMessages.length !== 0) {
    fail("blocked message_end must not queue a user message");
  }
  if (
    !notifications.some((message) =>
      message.includes("Communication Rules breach seen, correcting next reply."),
    )
  ) {
    fail("blocked message_end should show a facing notice");
  }

  // The pending flag drives a silent re-issue on the next context build, then
  // clears. The re-issue message is model-only (display:false).
  const reissueContext = handler("context")({ messages: [] }, facingCtx) as
    | { messages?: unknown[] }
    | undefined;
  const reissueMessages = Array.isArray(reissueContext?.messages)
    ? reissueContext.messages
    : [];
  const reissue = reissueMessages.find(
    (message): message is Record<string, unknown> =>
      typeof message === "object" &&
      message !== null &&
      (message as Record<string, unknown>).customType === "communication-rules-reissue",
  );
  if (!reissue) fail("context build should append the silent re-issue while flagged");
  if (reissue.display !== false) fail("re-issue message should be model-only (display:false)");
  if (typeof reissue.content !== "string" || !reissue.content.includes("breach detected")) {
    fail("re-issue message should carry the corrective framing");
  }

  const reissueAgain = handler("context")({ messages: [] }, facingCtx) as
    | { messages?: unknown[] }
    | undefined;
  const reissueAgainMessages = Array.isArray(reissueAgain?.messages)
    ? reissueAgain.messages
    : [];
  if (
    reissueAgainMessages.some(
      (message) =>
        typeof message === "object" &&
        message !== null &&
        (message as Record<string, unknown>).customType === "communication-rules-reissue",
    )
  ) {
    fail("re-issue flag should clear after one context build");
  }

  const blockedToolResult = handler("tool_result")(
    readFixture("tool-result-subagent-blocked.json"),
    context("tool-result"),
  ) as Record<string, unknown>;
  const blockedToolResultText = textFromResult(blockedToolResult);
  if (!blockedToolResultText.startsWith("Blocked. Revise this prose to follow the Communication Rules.")) {
    fail("blocked subagent tool_result should replace visible content");
  }
  if (blockedToolResultText.includes(leak)) {
    fail("blocked subagent tool_result should not expose the original payload");
  }
  if (blockedToolResult.isError !== true) {
    fail("blocked subagent tool_result should be marked as an error");
  }

  const cleanToolResult = handler("tool_result")(
    readFixture("tool-result-subagent-clean.json"),
    context("tool-result-clean"),
  );
  if (cleanToolResult !== undefined) fail("clean subagent tool_result should pass");

  // Tier B world output: the first strike on a blocked tool call blocks and
  // re-issues the rules to the model via reason.
  const toolCtx = context("tool-call");
  const writeBlock = handler("tool_call")(
    readFixture("tool-call-write-blocked.json"),
    toolCtx,
  ) as Record<string, unknown>;
  if (writeBlock.block !== true) fail("tool_call strike 1 should block");

  // The second strike on the same call content still blocks; the third yields,
  // lets the call run, and shows a short notice instead of blocking forever.
  const blockedToolEvent = readFixture("tool-call-write-blocked.json");
  const strikeTwo = handler("tool_call")(blockedToolEvent, toolCtx) as
    | Record<string, unknown>
    | undefined;
  if (strikeTwo?.block !== true) fail("tool_call strike 2 should block");
  const notifiesBeforeYield = notifications.length;
  const strikeThree = handler("tool_call")(blockedToolEvent, toolCtx);
  if (strikeThree !== undefined) fail("tool_call strike 3 should yield, not block");
  if (
    !notifications
      .slice(notifiesBeforeYield)
      .some((message) =>
        message.includes("Communication Rules unmet after retries, output allowed."),
      )
  ) {
    fail("tool_call yield should show a short notice");
  }

  // Sub-tier B2 external posts: irretractable once they yield, so five strikes.
  // Deny on strikes 1-4, yield on strike 5 with an error-level notice naming the
  // tool and target. The stable session+tool key means two distinct breaching
  // bodies still walk one budget rather than resetting.
  const externalCtx = context("external");
  const externalLeak = ["ro", "bust"].join("");
  function externalEvent(body: string): unknown {
    return {
      type: "tool_call",
      toolName: "mcp__github__add_issue_comment",
      toolCallId: "call-external",
      input: { issue_number: 42, body },
    };
  }
  const externalTool = handler("tool_call");
  for (let strike = 1; strike <= 4; strike += 1) {
    const result = externalTool(externalEvent(`${externalLeak} variant ${strike}`), externalCtx) as
      | Record<string, unknown>
      | undefined;
    if (result?.block !== true) fail(`external strike ${strike} should block`);
  }
  const notifiesBeforeExternalYield = notifications.length;
  const externalYield = externalTool(externalEvent(`${externalLeak} final variant`), externalCtx);
  if (externalYield !== undefined) fail("external strike 5 should yield, not block");
  if (
    !notifications
      .slice(notifiesBeforeExternalYield)
      .some((message) =>
        message.includes("error:Rules breach posted: mcp__github__add_issue_comment 42"),
      )
  ) {
    fail("external yield should show an operator notice naming the tool and target");
  }

  // Sub-tier B2 reset on pass: a clean post on the same session+tool clears the
  // stable counter, so a fresh breach starts again at strike 1 (block).
  externalTool(
    {
      type: "tool_call",
      toolName: "mcp__github__add_issue_comment",
      input: { issue_number: 42, body: "Done." },
    },
    externalCtx,
  );
  const externalReset = externalTool(externalEvent(`${externalLeak} after pass`), externalCtx) as
    | Record<string, unknown>
    | undefined;
  if (externalReset?.block !== true) fail("external breach after a clean pass should block at strike 1");

  console.log("pi extension fixtures passed");
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
