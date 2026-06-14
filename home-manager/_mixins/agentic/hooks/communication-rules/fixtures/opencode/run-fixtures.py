#!/usr/bin/env python3
"""Run focused OpenCode adapter helper fixtures."""

from __future__ import annotations

import os
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "fixtures" / "opencode"
ADAPTER = ROOT / "adapters" / "opencode.sh"
CONTRACT = ROOT / "adapters" / "contract.sh"
SCANNER = ROOT / "scanner.py"
RULES = ROOT / "communication-rules.md"
PLUGIN = ROOT.parents[1] / "opencode" / "plugins" / "communication-rules.ts"


def scanner_wrapper(temp_dir: Path) -> Path:
    path = temp_dir / "agent-communication-check"
    path.write_text(
        f"#!/usr/bin/env bash\nexec {sys.executable!r} {str(SCANNER)!r} --rules {str(RULES)!r} \"$@\"\n",
        encoding="utf-8",
    )
    path.chmod(0o755)
    return path


# Mirror the shared post-detection lists so the plugin exercises its policy.json
# load path. The values match fragment.nix's canonical source.
POLICY_POST_DETECTION = {
    "postToolTerms": [
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
    "postTextKeys": [
        "body",
        "comment",
        "comments",
        "content",
        "description",
        "message",
        "messages",
        "note",
        "notes",
        "review",
        "summary",
        "text",
        "title",
    ],
    "externalTargetKeys": [
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
}


def write_policy(temp_dir: Path) -> Path:
    path = temp_dir / "policy.json"
    path.write_text(
        json.dumps(
            {
                "communicationRules": {
                    "detectionPolicy": {"postDetection": POLICY_POST_DETECTION},
                },
            }
        ),
        encoding="utf-8",
    )
    return path


def run_adapter(command: str, fixture: str, *extra: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="opencode-scanner-") as temp:
        env = os.environ.copy()
        env["TRIPWIRE_ADAPTER_CONTRACT"] = str(CONTRACT)
        env["TRIPWIRE_SCANNER"] = str(scanner_wrapper(Path(temp)))
        return subprocess.run(
            ["bash", str(ADAPTER), command, *extra, str(FIXTURES / fixture)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            check=False,
        )


def run_adapter_payload(command: str, payload: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="opencode-payload-") as temp:
        temp_path = Path(temp)
        payload_path = temp_path / "payload.json"
        payload_path.write_text(payload, encoding="utf-8")
        env = os.environ.copy()
        env["TRIPWIRE_ADAPTER_CONTRACT"] = str(CONTRACT)
        env["TRIPWIRE_SCANNER"] = str(scanner_wrapper(temp_path))
        return subprocess.run(
            ["bash", str(ADAPTER), command, str(payload_path)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            check=False,
        )


def assert_exit(name: str, completed: subprocess.CompletedProcess[str], expected: int) -> None:
    if completed.returncode != expected:
        raise AssertionError(
            f"{name}: expected exit {expected}, got {completed.returncode}\n"
            f"stdout: {completed.stdout}\nstderr: {completed.stderr}"
        )


def assert_contains(name: str, completed: subprocess.CompletedProcess[str], text: str) -> None:
    if text not in completed.stdout:
        raise AssertionError(f"{name}: missing {text!r} in stdout:\n{completed.stdout}")


def assert_not_contains(name: str, completed: subprocess.CompletedProcess[str], text: str) -> None:
    if text in completed.stdout:
        raise AssertionError(f"{name}: unexpected {text!r} in stdout:\n{completed.stdout}")


def assert_last_line(name: str, completed: subprocess.CompletedProcess[str], expected: str) -> None:
    lines = [line for line in completed.stdout.splitlines() if line]
    if not lines or lines[-1] != expected:
        raise AssertionError(f"{name}: expected last line {expected!r}, got:\n{completed.stdout}")


def check_tool_pass(fixture: str) -> None:
    completed = run_adapter("tool-execute-before", fixture)
    assert_exit(fixture, completed, 0)
    if completed.stdout != "pass\n":
        raise AssertionError(f"{fixture}: expected pass only, got:\n{completed.stdout}")


def check_tool_block(fixture: str) -> None:
    completed = run_adapter("tool-execute-before", fixture)
    assert_exit(fixture, completed, 1)
    assert_contains(fixture, completed, "Blocked. Revise this prose to follow the Communication Rules.")
    assert_last_line(fixture, completed, "block")


def check_post_correction(fixture: str) -> None:
    completed = run_adapter("post-display", fixture)
    assert_exit(fixture, completed, 1)
    assert_contains(fixture, completed, "Revise the previous response to follow the Communication Rules.")
    assert_contains(fixture, completed, "correction-request")
    assert_not_contains(fixture, completed, "Blocked. Revise this prose")
    assert_not_contains(fixture, completed, "leverage")
    assert_not_contains(fixture, completed, "\\u2014")
    assert_not_contains(fixture, completed, "\\u2013")


def run_plugin_fixtures() -> None:
    bun = shutil.which("bun")
    if not bun:
        raise AssertionError("bun is required for OpenCode plugin fixtures")

    with tempfile.TemporaryDirectory(prefix="opencode-plugin-fixtures-") as temp:
        temp_path = Path(temp)
        scanner = scanner_wrapper(temp_path)
        plugin_source = PLUGIN.read_text(encoding="utf-8")
        plugin_source = plugin_source.replace("@tripwireAdapter@", str(ADAPTER))
        plugin_source = plugin_source.replace("@tripwireAdapterContract@", str(CONTRACT))
        plugin_source = plugin_source.replace("@tripwireScanner@", str(scanner))
        plugin_source = plugin_source.replace("@tripwireRules@", str(ROOT / "communication-rules.md"))
        plugin_source = plugin_source.replace("@tripwirePolicy@", str(write_policy(temp_path)))
        (temp_path / "communication-rules.ts").write_text(plugin_source, encoding="utf-8")

        harness = temp_path / "run-plugin-fixtures.ts"
        harness.write_text(
            """
import { CommunicationRules } from "./communication-rules.ts";

const fixtureDir = process.argv[2];
const logs: unknown[] = [];
const toasts: Array<{ body: { message: string; variant?: string } }> = [];
const client = {
  tui: {
    showToast: async (input: { body: { message: string; variant?: string } }) => {
      toasts.push(input);
      return {};
    },
  },
  app: {
    log: async (input: unknown) => {
      logs.push(input);
      return {};
    },
  },
};

const plugin = await CommunicationRules({ client });

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

async function readFixture(name: string): Promise<any> {
  return JSON.parse(await Bun.file(`${fixtureDir}/${name}`).text());
}

async function transform(sessionID: string): Promise<string[]> {
  const output: { system?: string[] } = {};
  await plugin["experimental.chat.system.transform"]({ sessionID }, output);
  return output.system ?? [];
}

const FACING_NOTICE = "Communication Rules breach seen, correcting next reply.";
const PRETOOLUSE_YIELD = "Communication Rules unmet after retries, output allowed.";
// The banned trigger word is assembled at runtime so this source file stays
// compliant with the very rules the harness exercises.
const trigger = ["Del", "ve"].join("");

const clean = await readFixture("post-display-clean.json");
const rulesText = (await Bun.file(`${fixtureDir}/../../communication-rules.md`).text()).trimEnd();

// Base rules inject once per session.
const systemOne = await transform("session-system");
assert(systemOne.length === 1, "system transform did not inject rules on fresh session");
assert(systemOne[0].includes("Communication Rules:"), "system transform missing rules text");

const systemTwo = await transform("session-system");
assert(systemTwo.length === 0, "system transform repeated rules in same session");

const systemThree = await transform("session-system-2");
assert(systemThree.length === 1, "system transform did not inject rules in new session");

// Tier A: a clean final does not flag a re-issue and does not toast.
await plugin["experimental.text.complete"](
  { sessionID: "session-1", messageID: "message-clean", partID: "part-clean" },
  { text: clean.message.content },
);
assert(toasts.length === 0, "clean final text raised a notice");

// Policy disclosure (the rules themselves) is allowed and raises nothing.
await plugin["experimental.text.complete"](
  { sessionID: "session-1", messageID: "message-disclosure", partID: "part-disclosure" },
  { text: rulesText },
);
assert(toasts.length === 0, "policy disclosure raised a notice");

// A blocked final flags a pending re-issue and toasts once, never re-rolling.
const finalBlocked = await readFixture("post-display-final-blocked.json");
await plugin["experimental.text.complete"](
  { sessionID: "session-1", messageID: "message-final", partID: "part-final" },
  { text: finalBlocked.message.content },
);
assert(toasts.length === 1, "blocked final did not toast a notice");
assert(toasts[0].body.message === FACING_NOTICE, "blocked final toast wrong message");
assert(toasts[0].body.variant === "error", "blocked final toast wrong variant");

// The first system.transform for session-1 injects the base rules and appends
// the silent re-issue, then clears the flag. session-1 only saw a text-complete
// above, so this is its first transform: base rules plus the re-issue, length 2.
const reissue = await transform("session-1");
assert(reissue.length === 2, "system transform did not inject base rules plus the re-issue");
const reissueSection = reissue.find((entry) => entry.includes("breach detected"));
assert(reissueSection !== undefined, "re-issue missing corrective framing");
assert(!reissueSection.includes("\\u2014"), "re-issue leaked em dash");

// The flag is one-shot: a later transform for the same session adds nothing.
const reissueAgain = await transform("session-1");
assert(reissueAgain.length === 0, "re-issue flag was not cleared after one transform");

// A blocked subagent message flags its own session and toasts.
const subagentBlocked = await readFixture("post-display-subagent-blocked.json");
await plugin.event({
  event: {
    type: "message.part.updated",
    properties: {
      part: {
        type: "tool",
        tool: "task",
        id: "part-subagent",
        sessionID: "session-2",
        messageID: "message-subagent",
        state: {
          status: "completed",
          output: subagentBlocked.message.content,
        },
      },
    },
  },
});
assert(toasts.length === 2, "blocked subagent did not toast a notice");
assert(toasts[1].body.message === FACING_NOTICE, "subagent toast wrong message");
const subagentReissue = await transform("session-2");
assert(subagentReissue.length === 2, "subagent session lacked base rules plus re-issue");

// Tier B world output: strikes 1 and 2 throw to block; the third for the same
// call content yields, lets the call run, and toasts a short notice.
const blockedArgs = { content: `${trigger} into the matter.` };
async function toolCall(): Promise<string | undefined> {
  try {
    await plugin["tool.execute.before"](
      { tool: "write", sessionID: "session-tool", callID: "call-tool" },
      { args: blockedArgs },
    );
    return undefined;
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
}

const strikeOne = await toolCall();
assert(typeof strikeOne === "string", "tool strike 1 should throw to block");
const strikeTwo = await toolCall();
assert(typeof strikeTwo === "string", "tool strike 2 should throw to block");
const toastsBeforeYield = toasts.length;
const strikeThree = await toolCall();
assert(strikeThree === undefined, "tool strike 3 should yield, not throw");
assert(toasts.length === toastsBeforeYield + 1, "tool yield should toast once");
assert(
  toasts[toasts.length - 1].body.message === PRETOOLUSE_YIELD,
  "tool yield toast wrong message",
);

// Strike reset on pass: a clean call clears the counter for that content key, so
// a fresh breach starts again at strike 1 (throw), never at the yield.
await plugin["tool.execute.before"](
  { tool: "write", sessionID: "session-reset", callID: "call-clean" },
  { args: { content: "Done." } },
);
const resetStrike = await (async () => {
  try {
    await plugin["tool.execute.before"](
      { tool: "write", sessionID: "session-reset", callID: "call-block" },
      { args: { content: `${trigger} into it.` } },
    );
    return undefined;
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
})();
assert(typeof resetStrike === "string", "fresh content should block at strike 1");

// Sub-tier B2 external posts (gh-api-safe): irretractable once they yield, so
// five strikes. Deny on strikes 1-4, yield on strike 5 with an error-variant
// toast that names the tool and target. The stable session+tool key means two
// distinct breaching bodies still walk one budget.
const EXTERNAL_YIELD = "Rules breach posted: gh-api-safe";
async function externalCall(body: string): Promise<string | undefined> {
  try {
    await plugin["tool.execute.before"](
      { tool: "gh-api-safe", sessionID: "session-ext", callID: "call-ext" },
      {
        args: {
          command: `gh-api-safe repos/x/y/issues/12/comments -X POST -f body='${body}'`,
        },
      },
    );
    return undefined;
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
}

for (let strike = 1; strike <= 4; strike += 1) {
  const result = await externalCall(`${trigger} variant ${strike}`);
  assert(typeof result === "string", `external strike ${strike} should block`);
}
const externalToastsBefore = toasts.length;
const externalYield = await externalCall(`${trigger} final variant`);
assert(externalYield === undefined, "external strike 5 should yield, not throw");
assert(toasts.length === externalToastsBefore + 1, "external yield should toast once");
assert(
  toasts[toasts.length - 1].body.message === EXTERNAL_YIELD,
  "external yield toast wrong message",
);
assert(
  toasts[toasts.length - 1].body.variant === "error",
  "external yield toast should use the error variant",
);

// Sub-tier B2 reset on pass: a clean external call clears the stable counter, so
// a fresh breach starts again at strike 1 (throw), never at the yield.
await plugin["tool.execute.before"](
  { tool: "gh-api-safe", sessionID: "session-ext-reset", callID: "call-ext-clean" },
  { args: { command: "gh-api-safe repos/x/y/issues/12 -X GET" } },
);
async function externalResetCall(body: string): Promise<string | undefined> {
  try {
    await plugin["tool.execute.before"](
      { tool: "gh-api-safe", sessionID: "session-ext-reset", callID: "call-ext-block" },
      {
        args: {
          command: `gh-api-safe repos/x/y/issues/12/comments -X POST -f body='${body}'`,
        },
      },
    );
    return undefined;
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
}
const externalReset = await externalResetCall(`${trigger} after pass`);
assert(typeof externalReset === "string", "external breach after a clean pass should block at strike 1");
""".strip()
            + "\n",
            encoding="utf-8",
        )

        completed = subprocess.run(
            [bun, str(harness), str(FIXTURES)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        assert_exit("plugin fixtures", completed, 0)


def main() -> int:
    expected = [
        "tool-write-clean.json",
        "tool-write-blocked.json",
        "tool-edit-blocked.json",
        "tool-patch-blocked.json",
        "tool-bash-blocked.json",
        "tool-post-clean.json",
        "tool-post-blocked.json",
        "tool-extraction-failure.json",
        "tool-duplicate-existing-blocked.json",
        "post-display-clean.json",
        "post-display-final-blocked.json",
        "post-display-subagent-blocked.json",
    ]
    missing = [name for name in expected if not (FIXTURES / name).is_file()]
    if missing:
        for name in missing:
            print(f"missing fixture: {name}", file=sys.stderr)
        return 2

    check_tool_pass("tool-write-clean.json")
    check_tool_pass("tool-post-clean.json")

    for fixture in [
        "tool-write-blocked.json",
        "tool-edit-blocked.json",
        "tool-patch-blocked.json",
        "tool-bash-blocked.json",
        "tool-post-blocked.json",
        "tool-extraction-failure.json",
    ]:
        check_tool_block(fixture)

    duplicate = run_adapter(
        "tool-execute-before",
        "tool-duplicate-existing-blocked.json",
        "--existing-blocked",
    )
    assert_exit("tool-duplicate-existing-blocked.json", duplicate, 1)
    if duplicate.stdout != "block\n":
        raise AssertionError(
            "tool-duplicate-existing-blocked.json: expected duplicate block suppression, got:\n"
            f"{duplicate.stdout}"
        )

    post_clean = run_adapter("post-display", "post-display-clean.json")
    assert_exit("post-display-clean.json", post_clean, 0)
    if post_clean.stdout != "pass\n":
        raise AssertionError(f"post-display-clean.json: expected pass only, got:\n{post_clean.stdout}")

    post_disclosure = run_adapter_payload(
        "post-display",
        json.dumps(
            {
                "event": "message.final",
                "surface": "final",
                "sessionID": "session-disclosure",
                "message": {
                    "content": RULES.read_text(encoding="utf-8").strip(),
                },
            }
        ),
    )
    assert_exit("post-display-policy-disclosure", post_disclosure, 0)
    if post_disclosure.stdout != "pass\n":
        raise AssertionError(
            "post-display-policy-disclosure: expected pass only, got:\n"
            f"{post_disclosure.stdout}"
        )

    check_post_correction("post-display-final-blocked.json")
    check_post_correction("post-display-subagent-blocked.json")
    run_plugin_fixtures()

    print("opencode fixtures passed: 13 adapter, 7 plugin")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
