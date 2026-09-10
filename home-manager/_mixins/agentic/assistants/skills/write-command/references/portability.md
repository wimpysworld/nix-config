# Command portability

Use the smallest portable set. Add fields only when a target needs them.

## Current Codex command contract

This repository emits commands as skills under the configured Codex skills path. Users invoke `$name`, not a custom slash command. Each command includes `agents/openai.yaml` with `policy.allow_implicit_invocation: false`. The composer owns this mandatory policy for plaintext and secret commands. Ordinary reusable skills retain their existing policies.

Codex receives accompanying arguments as user text. It does not substitute `$ARGUMENTS`, `$1..$9`, or `$NAMED` inside a command-derived skill. Map the text to the command's declared inputs explicitly. A nested `$child` token does not load another skill. Read the workflow instructions through the available catalogue or configured skill roots. Preserve the arguments, authority, and context owner when applying that body.

## Frontmatter matrix

| Field                      | Claude Code (legacy + skill-as-command) | OpenCode                                               | Pi                          | Codex (legacy `/prompts:`) |
| -------------------------- | --------------------------------------- | ------------------------------------------------------ | --------------------------- | -------------------------- |
| `description`              | optional (fallback: first body line)    | optional but recommended                               | optional (fallback)         | required for popup label   |
| `argument-hint`            | yes                                     | inferred from `$N`/`$ARGUMENTS` in body                | yes                         | yes                        |
| `model`                    | yes (`sonnet`/`opus`/`haiku`/full id)   | yes; ignored on ≤0.6.4                                 | no                          | no                         |
| `allowed-tools`            | yes, with `Bash(cmd:*)` filters         | no                                                     | no                          | no                         |
| `agent` binding            | implicit via `@<agent>` body prepend    | yes                                                    | no                          | no                         |
| `subtask` (fresh context)  | per-invocation (always fresh)           | `subtask: true` forces; default depends on bound agent | always fresh per invocation | no                         |
| `disable-model-invocation` | yes                                     | no                                                     | no                          | no                         |

## File location and invocation

| Platform    | Location                                                                  | Invocation                             |
| ----------- | ------------------------------------------------------------------------- | -------------------------------------- |
| Claude Code | `.claude/commands/<name>.md` (legacy) or `.claude/skills/<name>/SKILL.md` | `/<name>`                              |
| OpenCode    | `.opencode/commands/<name>.md` or `~/.config/opencode/commands/<name>.md` | `/<name>`                              |
| Pi          | `~/.pi/agent/prompts/<name>.md` or `.pi/prompts/<name>.md`                | `/<name>` (skills via `/skill:<name>`) |
| Codex       | `<configured-skills-root>/<name>/SKILL.md` plus `agents/openai.yaml`    | `$name` (manual-only command)          |
| Codex legacy | `~/.codex/prompts/<name>.md` (flat, no subdirs)                         | `/prompts:<name>` (removed in CLI 0.117.0) |

## Placeholder matrix

The Codex column below describes legacy custom prompts only, not current command-derived skills.

| Placeholder                             | Claude Code legacy                         | Claude Code skill-as-command   | OpenCode      | Pi                   | Codex legacy  |
| --------------------------------------- | ------------------------------------------ | ------------------------------ | ------------- | -------------------- | ------------- |
| `$ARGUMENTS`                            | yes (full string)                          | yes (full string)              | yes           | yes                  | yes           |
| `$1..$9`                                | undocumented                               | `$ARGUMENTS[N]`, **0-indexed** | **1-indexed** | **1-indexed**        | **1-indexed** |
| `$@`, `${@:N}`                          | no                                         | no                             | no            | yes (`${@:N:L}`)     | no            |
| `$NAMED` (e.g. `$KEY` with `KEY=value`) | no                                         | no                             | no            | no                   | yes           |
| `` !`cmd` ``                            | yes, requires `allowed-tools: Bash(cmd:*)` | yes                            | yes           | no                   | no            |
| `@path`                                 | yes                                        | yes                            | yes           | no (CLI prefix only) | no            |

## The `$1` hazard

`$1` does not mean the same thing everywhere. Pi, OpenCode, and legacy Codex custom prompts treat `$1` as the **first** positional argument. The new Claude Code skill-as-command format treats `$N` as `$ARGUMENTS[N]` with **0-based indexing**, so `$0` is the first argument and `$1` is the second. The legacy Claude Code command format does not document positional placeholders at all. Current Codex command-derived skills perform no placeholder substitution.

Rule for shared shims: use `$ARGUMENTS` for the full user text. On Codex, map that text explicitly. Preserve existing positional placeholders, but define their positions for runtimes without substitution.

## OpenCode `subtask` semantics

Default behaviour:

- No `agent:` bound, or `agent:` bound to a primary agent → command body runs in the **caller's session** (pollutes main context).
- `agent:` bound to a subagent → command body runs as a **subagent invocation** in a fresh context (no extra config needed).

`subtask: true` forces subagent invocation even when the bound agent is `mode: primary`. `subtask: false` keeps execution in the caller's session even when the bound agent is a subagent (spec-honoured; sst/opencode#10431 reports it ignored on some builds).

Claude Code and Pi have no equivalent field: every slash invocation runs in the caller's session unless the body explicitly dispatches through the Task tool (Claude) or `/skill:` / sub-agent invocation (Pi). For Claude Code, the repo-local `use-task: true` field in `header.claude.yaml` is the closest analogue.

## OpenCode `model:` honouring

OpenCode 0.6.4 and below ignored per-command `model:`; the fix shipped in a later release. Treat per-command model overrides as a hint on OpenCode, not a correctness guarantee.

## Codex coverage

Codex CLI 0.117.0 removed custom prompts. Use this repository's command composer for manual-only `$name` commands. Use `write-skill` for ordinary reusable skills. The companion `agents/openai.yaml` holds the invocation policy, not portable frontmatter.

## Cursor and Aider

Cursor accepts a Markdown-plus-frontmatter subset with `description` and `@file` references, but no positional argument syntax. Cover only if the repo decides to publish Cursor commands. Aider's slash commands are built-in and not user-extensible at the prompt-file layer; out of scope.
