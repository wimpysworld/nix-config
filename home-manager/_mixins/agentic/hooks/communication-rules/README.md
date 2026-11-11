# Communication Rules tripwire

One shared Python core, thin per-agent shims, and fixtures give advisory feedback on the [Communication Rules](../../assistants/styles/house-style/house-style.md) across Claude Code, Codex, Pi, and OpenCode. Nix reads the house style and generates the rules file, the core, and the policy once. Every agent runs the same core. Only the wiring differs.

## Status: initial PoC

This is an initial PoC. It is tightly integrated with this repository's Nix configuration, module layout, generated fragments, and per-agent hook wiring. It is not a drop-in tool yet.

A later version can become a stand-alone project with a smaller install path and clearer consumer API.

Example prompt for adapting it:

```text
Adapt the Communication Rules tripwire from this repository to my configuration.

Reference implementation: https://github.com/wimpysworld/nix-config/tree/main/home-manager/_mixins/agentic/hooks/communication-rules

Goals:
- Keep one source of truth for the rules text.
- Generate or install the scanner and agent-specific hooks from my config system.
- Check only newly authored prose with known provenance.
- Preserve exact technical content, imported artefacts, tool inputs, and results.
- Keep style feedback advisory and tool authorisation separate.
- Fail open on checker errors and send at most one compact notice per turn.
- Add fixtures for each agent hook I use.
- Keep the implementation self-contained and document every file I need to copy or replace.

First inspect my repository layout, then propose the smallest patch. Do not edit files until I approve the plan.
```

## Layout

- `scanner.py` is the CLI entry point for `<agent> <event>` and helper operations.
- `core/` holds the shared Python logic:
  - `types.py` defines shared types.
  - `detection.py` checks selected words and punctuation after protected content is excluded.
  - `config.py` reads the generated policy.
  - `state.py` deduplicates notices and stores pending feedback by session and user turn.
  - `responses.py` formats native feedback without permission decisions.
  - `dispatch.py` routes CLI requests and contains runtime failures.
  - `extractors/` identifies authored prose for Claude Code, Codex, OpenCode, and Pi.
- `pi/extensions/communication-rules/index.ts` and `opencode/plugins/communication-rules.ts` are thin client shims.
- `default.nix` provides `mkCommandHookAdapter` for Claude Code and Codex, and `mkPluginAdapter` for Pi and OpenCode.
- `fragment.nix` reads the canonical house style and generates the shared policy and rules assets.
- `fixtures/` contains scanner and client payloads. `tests/` contains Python and TypeScript suites.

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

## Advisory policy

The scanner checks selected lexical patterns, not full style conformance. Context decides whether a word is a precise technical term or a writing fault.

The canonical rules remain in [the house style](../../assistants/styles/house-style/house-style.md). Native instructions carry the rules into each client. Feedback names the rule and location instead of repeating the complete rules on each tool call.

### Scope

The scanner checks current assistant prose and positively identified publication fields. For recognised `gh` publication commands, extraction checks literal body and title arguments.

The scanner skips:

- Reads, searches, incoming tool results, and returned subagent artefacts.
- Local writes, edits, and patches whose prose provenance is unknown.
- Imported body files, shell source, and program source.
- Code, commands, URLs, identifiers, quotations, licences, and templates.

Unknown provenance means no style decision. Exact technical and imported content stays unchanged. A literal word match is not authority to rewrite evidence.

### Feedback and recovery

Style checks never deny a tool, grant permission, change inputs, replace results, block stopping, or start a correction-only turn. Fence and tool authorisation remain separate and authoritative.

A session receives at most one compact notice per user turn. Notices name the rule and location and stay within 320 characters. Final-message feedback waits for the next normal prompt or context request. Feedback does not force another turn.

Checker, extraction, decoding, timeout, and state errors fail open. Unknown sessions and unavailable state suppress feedback rather than risk repeated notices. No operator action is needed to recover authorised work from a style-check failure.

The core returns `pass` or `advisory`. Legacy surface labels remain internal compatibility fields, not enforcement tiers or strike budgets.

## Client integration

| Client | Native events | Advisory delivery |
| --- | --- | --- |
| Claude Code | `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `Stop` | Context and user notices without permission decisions. Final feedback waits for the next normal prompt. |
| Codex | `UserPromptSubmit`, `PreToolUse`, `Stop` | Context and user notices without permission decisions. No style `SessionStart` or `SubagentStart` registration. |
| OpenCode | V2 session `prompt` and `context`, tool `execute.before`, event `session.step.ended` | Prompt resets the turn. Context carries pending feedback. Final text is observed without replacement or resumed work. |
| Pi | `before_agent_start`, `context`, `tool_call`, `message_end` | Turn reset, pending context, and non-blocking notices. Only current assistant messages are checked. |

Command hooks omit permission decisions, including explicit `allow`. OpenCode and Pi catch style-check failures inside their handlers so that failures cannot reject tool calls.

Incoming subagent results are outside style checks. Claude Code and Codex do not register style `SubagentStop` hooks. Pi does not inspect `tool_result`.

The implementation does not use display transformations to rewrite assistant messages. The displayed answer, retained text, and returned artefacts stay consistent.

## Validation

Validate advisory behaviour with synthetic inputs and isolated state. Do not activate configurations, contact providers, or publish test messages.

The Python gate is `checks.<system>.communication-rules-hooks`, which CI and `just check` run. Its suites include:

- `run-scanner-fixtures.py`.
- `test_state_strikes.py`, `test_state_b2_reissue.py`, and `test_state_gaps.py`.
- `test_pi_native_subagents.py` and `test_pi_mcp_adapter.py`.

The strike-related filenames are historical. Their tests cover advisory deduplication, pending feedback, and fail-open behaviour, not permission retries.

`pi-shim.test.ts` and `opencode-shim.test.ts` check client boundaries, unchanged content, and injected failures.

Required regressions cover reads, exact imported content, known publication fields, interleaved reads, malformed responses, unavailable state, scanner exceptions, and timeouts. None must deny authorised work, replace results, override permissions, or start another turn.

Earlier live checks tested the retired blocking policy. They do not establish live validation of the advisory policy.
