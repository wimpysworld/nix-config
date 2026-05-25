# Command portability

Use the smallest portable set. Add fields only when a target needs them.

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
| Codex       | `~/.codex/prompts/<name>.md` (flat, no subdirs)                           | `/prompts:<name>` (deprecated)         |

## Placeholder matrix

| Placeholder                             | Claude Code legacy                         | Claude Code skill-as-command   | OpenCode      | Pi                   | Codex         |
| --------------------------------------- | ------------------------------------------ | ------------------------------ | ------------- | -------------------- | ------------- |
| `$ARGUMENTS`                            | yes (full string)                          | yes (full string)              | yes           | yes                  | yes           |
| `$1..$9`                                | undocumented                               | `$ARGUMENTS[N]`, **0-indexed** | **1-indexed** | **1-indexed**        | **1-indexed** |
| `$@`, `${@:N}`                          | no                                         | no                             | no            | yes (`${@:N:L}`)     | no            |
| `$NAMED` (e.g. `$KEY` with `KEY=value`) | no                                         | no                             | no            | no                   | yes           |
| `` !`cmd` ``                            | yes, requires `allowed-tools: Bash(cmd:*)` | yes                            | yes           | no                   | no            |
| `@path`                                 | yes                                        | yes                            | yes           | no (CLI prefix only) | no            |

## The `$1` hazard

`$1` does not mean the same thing everywhere. Pi, OpenCode, and Codex treat `$1` as the **first** positional argument. The new Claude Code skill-as-command format treats `$N` as `$ARGUMENTS[N]` with **0-based indexing**, so `$0` is the first argument and `$1` is the second. The legacy Claude Code command format does not document positional placeholders at all.

Rule for portable shims: use `$ARGUMENTS` when the whole user-typed string can pass through unchanged. Reserve `$1..$9` for command bodies consumed exclusively by Pi / OpenCode / Codex where position-by-position split is essential.

## OpenCode `subtask` semantics

Default behaviour:

- No `agent:` bound, or `agent:` bound to a primary agent → command body runs in the **caller's session** (pollutes main context).
- `agent:` bound to a subagent → command body runs as a **subagent invocation** in a fresh context (no extra config needed).

`subtask: true` forces subagent invocation even when the bound agent is `mode: primary`. `subtask: false` keeps execution in the caller's session even when the bound agent is a subagent (spec-honoured; sst/opencode#10431 reports it ignored on some builds).

Claude Code and Pi have no equivalent field: every slash invocation runs in the caller's session unless the body explicitly dispatches through the Task tool (Claude) or `/skill:` / sub-agent invocation (Pi). For Claude Code, the repo-local `use-task: true` field in `header.claude.yaml` is the closest analogue.

## OpenCode `model:` honouring

OpenCode 0.6.4 and below ignored per-command `model:`; the fix shipped in a later release. Treat per-command model overrides as a hint on OpenCode, not a correctness guarantee.

## Codex coverage

Codex custom prompts are deprecated. Skills are the supported route for reusable invocation on Codex. Cover Codex briefly here; point new Codex work at `write-skill` and the companion `agents/openai.yaml` UI metadata file.

## Cursor and Aider

Cursor accepts a Markdown-plus-frontmatter subset with `description` and `@file` references, but no positional argument syntax. Cover only if the repo decides to publish Cursor commands. Aider's slash commands are built-in and not user-extensible at the prompt-file layer; out of scope.
