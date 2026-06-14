# Communication Rules tripwire

Shared scanner, adapters, and fixtures enforce the [Communication Rules](communication-rules.md) across Claude Code, Codex, Pi, and OpenCode. Nix generates the rules fragment, scanner, and policy once; each agent wires its own adapter.

## Status: initial PoC

This is an initial PoC. It is tightly integrated with this repository's Nix configuration, module layout, generated fragments, and per-agent hook wiring. It is not a drop-in tool yet.

A later version may become a stand-alone project with a smaller install path and clearer consumer API.

Example prompt for adapting it:

```text
Adapt the Communication Rules tripwire from this repository to my configuration.

Reference implementation: https://github.com/wimpysworld/nix-config/tree/main/home-manager/_mixins/agentic/hooks/communication-rules

Goals:
- Keep one source of truth for the rules text.
- Generate or install the scanner and agent-specific hooks from my config system.
- Preserve the two-tier policy: block world-visible writes and posts before they run; treat final assistant prose as best-effort correction for the next turn.
- Strip fenced code before scanning.
- Add fixtures for each agent hook I use.
- Keep the implementation self-contained and document every file I need to copy or replace.

First inspect my repository layout, then propose the smallest patch. Do not edit files until I approve the plan.
```

## Layout

- `scanner.py` deterministic checker for banned words, dashes, and policy disclosure.
- `adapters/` per-agent extraction and gating shims over the shared `contract.sh`.
- `fragment.nix` generates the rules text, reminder, block, and correction prompts.
- `fixtures/` and `tests/` per-agent expected-behaviour cases.

## Why this exists

The Communication Rules keep agent output short, plain, and easy to read. They serve two goals.

First, clarity and productivity. A reader gets the answer in fewer words. A non-native English speaker understands it on the first read.

Second, the rules are policy for the token-optimised agent loop. The loop is described in the [assistants instructions README](../../assistants/instructions/README.md). Parent context is permanent and finite, so every extra word costs the loop. Terse, on-rule output is part of that economy, not a style preference.

That economy has a cash cost too: token-efficient replies cost less, arrive faster, and stretch API spend and subscription allowances further. Caveman prompt users can paint ten-screen answers on a cave wall; here the rule is: get to the fucking point.

There is early evidence that brevity can improve answer quality, not only cost. The March 2026 paper ["Brevity Constraints Reverse Performance Hierarchies in Language Models"](https://arxiv.org/abs/2604.00025) found that constraining large models to brief responses improved accuracy by 26 points on certain benchmarks.

### Comparison

Each row is one query asked twice on Opus 4.8 via Claude Code: before is the default answer, after is the same answer under the Communication Rules. Tokens are the headline metric.

| Query                        | Before | After | Saved | Saved % |
| ---------------------------- | -----: | ----: | ----: | ------: |
| Explain git rebase vs merge  |    879 |   333 |   546 |   62.1% |
| Explain mutex vs semaphore   |    857 |   452 |   405 |   47.3% |
| Explain processes vs threads |   1076 |   401 |   675 |   62.7% |
| Explain TCP vs UDP           |   1184 |   368 |   816 |   68.9% |
| Explain REST vs GraphQL      |   1474 |   379 |  1095 |   74.3% |
| Explain SQL vs NoSQL         |   1604 |   519 |  1085 |   67.6% |

## Design principles

These principles shape the gate.

**The sensor is deterministic and independent of the model.** Detection cannot ask another LLM to judge, because LLM output is probabilistic. The gate is a stdlib-only Python scanner with exact, mechanically testable checks: the em and en dash characters, and an exact-match subset of the banned words. The thing that controls the model must not be the model. That keeps the gate testable with fixtures and stops a bad model from talking its way past its own checker.

**Agent tells are alignment signals.** The em dash and other banned tells are the habits agents drift back to when attention drops or context is stretched. Their emergence means the agent is no longer aligned with the Communication Rules. On blockable output, the hook punches the agent in the face, blocks the transgressed output, re-issues the Communication Rules, and asks it to try again.

**One source of truth feeds the model and the gate.** Nix generates a single Communication Rules fragment. The same fragment feeds global instructions, every generated subagent prompt, session reminders, and the hook re-issue text. So what the model is told and what the gate enforces cannot drift apart.

**Each agent uses its own best native mechanism.** The design does not force one shared hook model across the four agents. Each adapter uses the hook or extension that fits its platform, so output contracts differ per agent (see the table below).

## The core constraint

No agent can block streamed prose before the user sees it. By the time a hook fires on a final message, the words are already on screen.

So enforcement is best-effort. It is tuned to keep the model aligned over time, not to perfect a single message. We accept that the odd breach is surfaced, and we correct the next reply.

## The two tiers

Enforcement scales to blast radius. The hook surface decides the tier.

### Tier B: world-visible output

This covers writes, edits, patches, Bash command bodies, and post bodies (gh and MCP). These are intercepted before they run, so a breach can still be stopped.

The policy is strike-then-yield, split by blast radius into two sub-tiers:

- **B1 (local): writes, edits, patches, and Bash command bodies.** Cheap to retract because they land on disk, not committed. Three strikes, keyed per tool-call content. Strikes 1 and 2 block and re-issue the rules; strike 3 yields with a short notice.
- **B2 (external): gh, gh-api-safe, MCP posts, and gh posts run through Bash.** Irretractable the instant they yield. Five strikes, keyed on a stable identity (session and tool, no body) so reworded retries of the same post draw down one budget. Strikes 1 to 4 block and re-issue; strike 5 yields with an operator-visible notice that names the tool and target (`Rules breach posted: <target>`).

We retry, then yield. Blocking automation forever is friction users will not accept. The local path tries twice; the external path tries four times before the irreversible yield. The cost is that imperfect output is sometimes surfaced after the retries.

A Bash call is external when its first token is `gh` or `gh-api-safe` and it carries a post signal (a body-bearing flag or a POST/PATCH/PUT method); read-only gh calls stay local.

### Tier A: user-facing and agent-facing prose

This covers the final assistant message and subagent or agent-to-agent prose. These cannot be blocked before the reader sees them, so they are never blocked and never re-rolled.

On a flagged final message:

- The model gets a silent re-issue of the rules so it self-corrects on the next turn. The user does not see this.
- The user sees a short notice that a breach was seen and acted on.

There is no strike loop here. We never block, so each offending turn gets one re-issue plus one notice. We tolerate the odd miss.

## What is inspected

The gate scans only prose the agent emits as its own words:

- File writes.
- Edits and patch additions.
- External post bodies (gh, gh-api-safe, post-capable MCP).
- Agent-to-agent and subagent prose.
- Final replies.

Fenced code blocks are stripped before scanning, so code is never flagged. Quoted dashes or banned words that remain in prose are blocked by design; if the agent writes them as its own text, it owns them.

The gate does not scan:

- Incoming tool output. It may quote external text the agent does not own, so blocking on it would punish the agent for words it did not write.
- Arbitrary Bash arguments.
- Binary content.
- Build logs.
- External text the agent is reading, not posting as its own.

Bash scanning stays narrow on purpose. It covers obvious prose side effects and recognised gh or gh-api-safe post bodies, not a full shell parse. A Bash post body whose outgoing text cannot be read fails closed, the same as any other uninspectable write, edit, or post.

## Per-agent validation matrix

Each platform uses its native hook surface. Validate the same behaviours per agent: side-effect checks run before the action, final-prose checks never block, and pending re-issue happens once.

Every Tier B adapter uses the same retry split:

- B1 local output (`write`, `edit`, `patch`, Bash) blocks twice, then yields on the third strike with `Communication Rules unmet after retries, output allowed.`
- B2 external output (`gh`, `gh-api-safe`, post-capable MCP tools, gh posts through Bash) blocks four times, then yields on the fifth strike with `Rules breach posted: <target>`.
- B1 keys use a stable local target when available (`session + tool + path`, plus `turn` on Codex). Bash and pathless calls fall back to `session + tool`. B2 keys use stable `session + tool` identity, plus `turn` on Codex.

| Agent       | Hooks used                                                                                                                            | Detection                                                                                                                                                                                                                                                                     | User notification                                                                                                                                                                                                                                                   | Rules re-issued                                                                                                                                                                                                                                                                                                                                                                            |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Claude Code | `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `Stop`, `SubagentStop`.                                                             | `PreToolUse` scans writes, edits, patches, Bash prose side effects, MCP post bodies, and gh post bodies. `Stop` and `SubagentStop` scan the last assistant or subagent prose. Extraction failure on Tier B fails closed.                                                      | Tier B deny returns `permissionDecisionReason` to the model. Tier B yield returns an allow reason visible to the user. Tier A breach emits one `systemMessage`: `Communication Rules breach seen, correcting next reply.`                                           | `SessionStart` injects the full rules reminder for fresh sessions. Tier B deny re-issues the full block message. Tier A sets a pending flag; the next `UserPromptSubmit` injects the correction prompt as `additionalContext`, then clears the flag.                                                                                                                                       |
| Codex       | `SessionStart`, `SubagentStart`, `UserPromptSubmit`, `PreToolUse`, `Stop`, `SubagentStop`.                                            | `PreToolUse` scans `apply_patch`, `Edit`, `Write`, `Bash`, post-capable MCP tools, gh tools, and gh posts through Bash. `Stop` and `SubagentStop` scan assistant and subagent prose. Extraction failure on Tier B fails closed.                                               | Tier B deny uses `permissionDecisionReason`; Codex `additionalContext` is not used on `PreToolUse`. Tier B yield uses allow reason. Tier A breach emits `systemMessage`: `Communication Rules breach seen, correcting next reply.`                                  | `SessionStart` and `SubagentStart` inject the full rules reminder for fresh contexts. Tier B deny re-issues the full block message. Tier A sets a pending flag; the next `UserPromptSubmit` injects the correction prompt as `additionalContext`, then clears the flag. Nix pre-seeds hook `trusted_hash` state in `config.toml`, so generated hooks are trusted without a runtime prompt. |
| OpenCode    | `experimental.chat.system.transform`, `tool.execute.before`, `experimental.text.complete`, `event` for completed subagent tool parts. | `tool.execute.before` scans writes, edits, patches, Bash prose side effects, post bodies, and gh post bodies. `experimental.text.complete` scans final prose. `event` scans completed `task`, `agent`, or `subagent` output. Adapter errors fail closed under the strike cap. | Tier B blocks by throwing the block message. Tier B yield shows a toast and logs a warning fallback. Tier A breach shows a toast: `Communication Rules breach seen, correcting next reply.`                                                                         | `experimental.chat.system.transform` injects the full rules once per session key. It does not repeat the full prompt after that. Tier B throw re-issues the full block message. Tier A sets a pending flag; the next system transform appends the correction prompt, then clears the flag.                                                                                                 |
| Pi          | `context`, `tool_call`, `message_end`, `tool_result`.                                                                                 | `tool_call` scans writes, edits, patches, Bash prose side effects, post bodies, and gh post bodies. `message_end` scans final prose after skipping intermediate `toolUse` turns. `tool_result` scans subagent output. Extraction failure on Tier B fails closed.              | Tier B blocks by returning `{ block = true, reason = ... }`. Tier B yield uses `ctx.ui.notify` when UI exists. Tier A breach notifies: `Communication Rules breach seen, correcting next reply.` `tool_result` breaches return an error content block to the model. | `context` appends the full rules as a hidden custom message when absent. It does not repeat the full prompt once present. Tier B block re-issues the full block message. Tier A sets a pending flag; the next `context` hook appends a hidden `display:false` correction message, then clears the flag.                                                                                    |

Full Communication Rules injection is limited to fresh session, subagent, or context creation. Retry and final-prose paths use the correction prompt instead, so the model is corrected without repeated prompt injection.

The explicit verbatim disclosure override is part of the scanner policy. A user request to view, repeat, disclose, print, or test the Communication Rules passes when the output is the canonical rules text.

### Validation status

Tested on 2026-06-14. Claude Code and Codex were tested live. OpenCode now has fixture, installed-plugin, live local tool-call, headless final-text, and GitHub post-block coverage. Pi now has live chat, local tool-call, GitHub post-block, and subagent-output coverage. OpenCode TUI toast rendering was not directly observed. Pi live testing confirmed the Tier A notice and next-turn re-issue in chat.

| Behaviour                                    | Claude Code                     | Codex                                           | OpenCode                                        | Pi                                                     |
| -------------------------------------------- | ------------------------------- | ----------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------ |
| Hook install and trust                       | Pass (live)                     | Pass (live)                                     | Pass (live: Home Manager activation and reload) | Pass (live: hooks active)                              |
| Fresh-context rules reminder                 | Pass (live: `SessionStart`)     | Pass (live: `SessionStart` and `SubagentStart`) | Pass (installed plugin)                         | Pass (fixtures)                                        |
| Quiet prompt hook without pending re-issue   | Pass (live)                     | Pass (live)                                     | Pass (installed plugin)                         | Pass (fixtures)                                        |
| Tier B clean output                          | Pass (live)                     | Pass (live)                                     | Pass (live: patch and Bash redirect)            | Pass (live: write and Bash)                            |
| Tier B detection and block                   | Pass (live)                     | Pass (live)                                     | Pass (live: patch, Bash redirect, gh post)      | Pass (live: write, Bash, gh post)                      |
| Tier B strike-then-yield                     | Pass (live: B1 cycle, B2 block) | Pass (live: B1 cycle, B2 block)                 | Pass (live: B2 block; installed plugin: B1)     | Pass (live: B1 cycle, B2 block; fixtures: B2 yield)    |
| Tier B block notice to user                  | Pass (live)                     | Pass (live)                                     | Partial (live: Bash reason absent; fixtures)    | Pass (live: block reason returned)                     |
| Tier A detection and pending flag            | Pass (live)                     | Pass (live)                                     | Pass (installed plugin)                         | Pass (live)                                            |
| Tier A next-turn re-issue                    | Pass (live)                     | Pass (live)                                     | Pass (installed plugin)                         | Pass (live)                                            |
| Tier A pending flag clear                    | Pass (live)                     | Pass (live)                                     | Pass (installed plugin)                         | Pass (live)                                            |
| Tier A user notice                           | Fail (live)                     | Pass (live)                                     | Pass (live: final-text append and log fallback) | Pass (live)                                            |
| Canonical rules disclosure                   | Pass (live)                     | Pass (live)                                     | Pass (installed plugin)                         | Pass (live: canonical write allowed)                   |
| Subagent prose follows final-prose behaviour | Pass (live: `SubagentStop`)     | Pass (live: `SubagentStop`)                     | Pass (installed plugin)                         | Partial (live: block path; one encoded prompt escaped) |

Notes:

- The Claude Code Tier A user notice fails. The Stop hook emits the `systemMessage`, but Claude Code does not show it to the user. This is a known lower-priority follow-up.
- B2 external block is live-verified on Claude Code: a real gh issue create was denied on strike 1 and never posted. The strike-5 yield stays fixture-only on every agent, since a live yield would post to GitHub irreversibly.
- B2 external block is live-verified on Codex: `gh repo view owner/private-test-repo --json nameWithOwner,isPrivate` passed, then `gh issue create` with a rule-breaking body was blocked and no issue was created.
- Codex live validation covered Tier B clean and block paths, the B1 strike-then-yield cycle, and a B2 external block. B2 external yield stays fixture-only for the same irreversible-post reason.
- OpenCode live validation covered 50 scanner fixtures, 15 adapter fixtures, 8 plugin fixtures, clean `apply_patch` with a rule-breaking removed line, blocked `apply_patch` with a rule-breaking added line, clean Bash redirect write, blocked Bash rule-breaking redirect, headless Tier A final-text notice append with log fallback, and a blocked private `gh issue create`; the issue list was unchanged.
- Pi live validation covered Tier A chat detection, visible notice, next-turn correction re-issue, and pending flag clear. It also covered clean local writes, clean Bash prose output, local write blocks, Bash prose blocks, B1 local strike-then-yield on the third attempt, canonical rules write allowance, and a real private `gh issue create` attempt; the post body was blocked and no issue was created.
- Pi subagent validation covered `tool_result` block behaviour for direct rule-breaking subagent output, including long-dash output. One encoded filler-word prompt escaped through a subagent result, so subagent prose coverage is marked partial until that bypass is fixed or explained.
- OpenCode TUI toast rendering remains unobserved; fixtures verify toast and log calls only. Bash rule-breaking redirect blocked the side effect, but this UI did not show the block reason for that probe.
- OpenCode B2 yield stays fixture-only because a live yield would post to GitHub irreversibly.
- The Claude Code B1 strike-then-yield was driven with three different bodies to one path: block, block, then yield on the third. This also confirms the stable strike key, since the changed content still drew down one budget.
- Codex `CODEX_HOME` is set; hooks wired once, including one `UserPromptSubmit`; trust entries enabled

## Fail-closed and disclosure

Tier B stays fail-closed: if extraction fails on a world-output surface, the call is denied under the same strike cap rather than letting unscanned prose through. A write, edit, or post whose outgoing prose cannot be read is treated as a breach, not waved through.

There is no agent bypass. No flag, env var, allow rule, or prompt escape lets an agent skip the gate. The operator can still recover from a false positive: disable hooks through the operator-owned mechanism, or rebuild without this mixin. That recovery sits outside the inspected agent action, so it is operator control, not an agent bypass.

The re-issue hides the trigger. It asks for full Communication Rules compliance and never names the specific dash or word that fired. If the model learned which single trigger it tripped, it could treat that as a cheat code, avoid that one thing, and ignore the rest of the rules.

The scanner allows the rules themselves through, so a request to view or quote the Communication Rules is not flagged as a breach.
