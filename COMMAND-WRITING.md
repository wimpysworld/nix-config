# Command Writing Research

Companion to `SKILL-WRIITING.md` and `PROMPT-WRITING.md`. Assesses Rosey's existing slash-command estate (six shims + `handover` + five standalone commands) against current best practice and proposes a fourth writing skill, `write-command`, with `/create-command` and `/update-command` shims.

## 1. Sources consulted

| # | Source | URL | Accessed | Authority |
|---|---|---|---|---|
| C1 | Anthropic - Slash Commands in the SDK (legacy `.claude/commands/`) | https://code.claude.com/docs/en/agent-sdk/slash-commands | 2026-05-24 | Vendor docs. Documents the legacy command file format, `argument-hint`, `allowed-tools`, `description`, `model`, `@file`, `!bash`. Notes the format is "legacy" and recommends migrating to `.claude/skills/<name>/SKILL.md` for new work. |
| C2 | Anthropic `claude-code` `command-development` skill - README | https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/command-development/README.md | 2026-05-24 | Anthropic-shipped command-authoring skill. Single source of truth for current command doctrine: frontmatter, `$ARGUMENTS`/`$N`, `@`/`!` placeholders, organisation, best practices, validation. |
| C3 | Anthropic `command-development` frontmatter reference | …/command-development/references/frontmatter-reference.md | 2026-05-24 | Field-by-field spec for `description`, `allowed-tools` (with `Bash(git:*)` filter syntax), `model`, `argument-hint`, `disable-model-invocation`. Best-practice phrasing per field. |
| C4 | Anthropic - Extend Claude with skills (merged command/skill section) | https://docs.anthropic.com/en/docs/claude-code/skills | 2026-05-24 | States `.claude/commands/x.md` and `.claude/skills/x/SKILL.md` are merging: both yield `/x`. The new format uses `$ARGUMENTS[N]`/`$N` with **0-based indexing** (`$0` is first arg). Named `arguments:` frontmatter maps positions to names. |
| C5 | Anthropic - Hooks reference (UserPromptExpansion) | https://docs.anthropic.com/en/docs/claude-code/hooks | 2026-05-24 | Confirms slash-command lifecycle: commands expand to a prompt, hooks can inject `additionalContext` or block expansion. Relevant for declared side effects. |
| C6 | OpenCode - Commands docs | https://opencode.ai/docs/commands ; mirrored at https://github.com/anomalyco/opencode/blob/dev/packages/web/src/content/docs/commands.mdx | 2026-05-24 | Vendor docs. Frontmatter: `description`, `agent`, `model`, `subtask`. Body is a template; placeholders `$ARGUMENTS`, `$1..$9`, `!bash`, `@file`. Built-ins: `/init`, `/review` (the latter with `subtask: true`). |
| C7 | OpenCode source - `command/index.ts` `Info` schema (via OpenCode-Book ch.14.3) | https://www.opencodebook.xyz/en/chapter_14_skill_system/14.3_command_system | 2026-05-24 | Confirms canonical fields and the unified `command`/`mcp`/`skill` source model. `$1` is 1-indexed (first positional arg). |
| C8 | OpenCode issue #2461 - `model` ignored in 0.6.4 | https://github.com/sst/opencode/issues/2461 | 2026-05-24 | Vendor bug report (acknowledged, fixed in later PR). Affects shim model pinning: do not rely on per-command `model` on older OpenCode versions; the conversation model wins. |
| C9 | OpenAI Codex - Custom Prompts (deprecated) | https://developers.openai.com/codex/custom-prompts | 2026-05-24 | Codex vendor doc. Frontmatter: `description`, `argument-hint`. Placeholders: `$1..$9`, `$ARGUMENTS`, `$NAMED`, `$$` for literal `$`. Stored under `~/.codex/prompts/`, invoked as `/prompts:<name>`. **Custom prompts are deprecated**; Codex now recommends skills for both explicit and implicit invocation. |
| C10 | OpenAI Codex - Customization (skills as the replacement) | https://developers.openai.com/codex/concepts/customization | 2026-05-24 | Skills are the supported route for reusable invocation on Codex; companion `agents/openai.yaml` handles UI metadata. Slash commands are not part of Codex's current product surface beyond legacy `/prompts:`. |
| C11 | Pi `prompt-templates.md` (v0.75.3 docs) | …/pi-coding-agent/docs/prompt-templates.md | 2026-05-24 | Pi prompt templates: frontmatter `description`, `argument-hint`. Substitution `$1..$9`, `$@`, `$ARGUMENTS`, `${@:N}`, `${@:N:L}`. `$1` is **1-indexed**. Invoked as `/<name>`. |
| C12 | Pi source - `prompt-templates.ts` (`substituteArgs`) | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/src/core/prompt-templates.ts | 2026-05-24 | Authoritative substitution semantics in Pi's source: `$N` (1-indexed) processed before wildcards; values containing `$1` are not recursively substituted. |
| C13 | Pi `usage.md` and `rpc.md` (commands surface) | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/usage.md | 2026-05-24 | Pi commands come from three sources (extension, prompt template, skill). Prompt templates expand client-side before the message is sent. No agent-scoped namespace; flat `/name`. |
| C14 | OpenCode `command-creator` skill (community) | https://playbooks.com/skills/igorwarzocha/opencode-workflows/command-creator | 2026-05-24 | Community skill but useful normative phrasing: "Commands are for USERS", placeholder table, single-responsibility rule. Confirms `$ARGUMENTS`, `$1..$9`, `!bash`, `@file` are the OpenCode placeholder set. |
| C15 | Cursor - Custom Commands (`.cursor/commands/`) | https://docs.cursor.com/en/agent/custom-commands | 2026-05-24 | (Site reachable; only relevant insight: Cursor stores Markdown files with a YAML preamble of `description`, supports `@file` and free-text instructions; no positional argument syntax. Treat as portable-Markdown target.) |
| C16 | Aider - In-chat commands | https://aider.chat/docs/usage/commands.html | 2026-05-24 | Aider's slash commands are built-in (`/add`, `/diff`, etc.) and not user-extensible via prompt files. Not a portability target for `write-command`. |
| C17 | `TOKEN-EFFICIENT-LOOP.md` (this repo) | n/a | 2026-05-24 | Doctrine: stable prefixes for prompt caching, fresh-context-first for delegation, verbatim relay, response contract owned by `delegate-task`. |
| C18 | `PROMPT-WRITING.md` (this repo) | n/a | 2026-05-24 | Prior research that produced `write-agents-md` and `write-assistant`. Confirms Pi argument-passing (`$1`, `$@`, `$ARGUMENTS`, `${@:N}`) and the shim pattern. |
| C19 | `SKILL-WRIITING.md` (this repo) | n/a | 2026-05-24 | Prior research that produced `write-skill`. Establishes the shim-plus-shared-skill reorg pattern and the writing-skill portability table shape. |

Notes:

- C2/C3 are the highest-authority current sources because Anthropic ships its own command-authoring skill openly, with field-level guidance.
- C9 is paywall-free but **flags Codex custom prompts as deprecated**. This is the single biggest portability shift since `SKILL-WRIITING.md` was written. `write-command` must lead with skills-as-the-target on Codex, with the legacy `/prompts:` route as a fallback.
- C8 and C12 are direct source/issue evidence and overrule any older third-party gloss.

## 2. Slash-command best practice synthesis

### 2.1 The portable core

Every supported platform reads:

- A Markdown file with optional YAML frontmatter.
- A `description` field shown in completion UI.
- A body that is treated as a literal user prompt at invocation time.
- A positional-argument and/or `$ARGUMENTS` substitution scheme.

That portable core is all the repo needs to commit to. Vendor extensions (`allowed-tools`, `model`, `agent`, `subtask`, named arguments, hooks) layer on top per target.

### 2.2 Vendor matrix (frontmatter and placeholders)

| Aspect | Claude Code (legacy command + new skill-as-command) | OpenCode | Codex (legacy custom prompts; deprecated) | Pi prompt templates |
|---|---|---|---|---|
| File location | `.claude/commands/<name>.md` (legacy) **or** `.claude/skills/<name>/SKILL.md` (current) | `.opencode/commands/<name>.md` or `~/.config/opencode/commands/<name>.md` | `~/.codex/prompts/<name>.md` (flat, no subdirs) | `~/.pi/agent/prompts/<name>.md` or `.pi/prompts/<name>.md` |
| Invocation | `/<name>` | `/<name>` | `/prompts:<name>` | `/<name>` (skills as `/skill:<name>`) |
| `description` | Optional; first line of body fallback (C2/C3) | Optional but recommended (C6) | Required for the popup label (C9) | Optional; first body line fallback (C12) |
| `argument-hint` | Yes (C3) | Listed as `hints` in source schema (C7); accepts string in markdown | Yes (C9) | Yes (C11/C12) |
| `model` | Yes (`sonnet`/`opus`/`haiku`/full id) (C3) | Yes but ignored on ≤0.6.4 (C6, C8); honoured in current builds | No (model controlled by Codex session) | No (model controlled by Pi session) |
| Tool restriction | `allowed-tools` with `Bash(cmd:*)` filters (C3) | None at frontmatter level | None | None |
| Agent binding | Skill format only: `agent:` in frontmatter; legacy commands rely on `@<agent>` prepend | `agent: <name>` (C6) | None | None (Pi has no agent-scoped command namespace; C13) |
| Subtask / fresh context | Implicit; new context per invocation | `subtask: true` runs in a sub-session (C6) | n/a | n/a (parent-context replacement only) |
| Manual-only | `disable-model-invocation: true` (C3) | n/a | n/a | n/a |
| Positional args | `$ARGUMENTS` (full), `$ARGUMENTS[N]`/`$N` **0-indexed** in new skill format (C4); legacy commands traditionally `$ARGUMENTS` only | `$ARGUMENTS`, `$1..$9` **1-indexed** (C6/C7) | `$ARGUMENTS`, `$1..$9` **1-indexed**, plus named `$KEY` (`KEY=value`) (C9) | `$ARGUMENTS`, `$@`, `$1..$9` **1-indexed**, plus `${@:N}` slicing (C11/C12) |
| Bash injection | `` !`cmd` `` requires `allowed-tools: Bash(cmd:*)` (C2) | `` !`cmd` `` (C6/C14) | None documented (C9) | None documented (C11) |
| File ref | `@path` (C2) | `@path` (C6) | None | `@path` works only as a CLI message prefix, not inside templates (C13) |
| Lifecycle hook | `UserPromptExpansion` hook can inject context or block (C5) | None | None | None |

Cursor (C15) and Aider (C16) sit outside this matrix: Cursor accepts a small Markdown subset (no positional args); Aider's commands are non-extensible. Neither is a delivery target for this repo.

### 2.3 The cross-platform `$1` hazard

`$1` does not mean the same thing everywhere:

- Pi, OpenCode, Codex: `$1` is the **first** positional argument. (C6, C7, C9, C11, C12.)
- Claude Code, new skill-as-command format: `$N` is `$ARGUMENTS[N]` with **0-based indexing**, so `$0` is the first argument and `$1` is the *second*. (C4.)
- Claude Code, legacy `.claude/commands/<name>.md`: the public docs lead with `$ARGUMENTS` and do not document positional placeholders for the legacy format (C1, C2). The community/cc-sdd mirror confirms `$ARGUMENTS` is the documented variable; positional placeholders behave inconsistently across CC versions.

Practical rule for portable shims targeting the four platforms in this repo: use `$ARGUMENTS` when the whole user-typed string can be passed through unchanged, and avoid `$1` unless the body is **only** rendered for Pi/OpenCode/Codex. The current Rosey shims rely on `$1` everywhere; on Claude Code this either reads as the second positional arg or silently expands empty. See §5.

### 2.4 Recommended portable structure (synthesis)

```markdown
---
description: <one-line label shown in completion>
argument-hint: "<[optional] or <required> argument shape>"
---

## <Title>

<One imperative sentence stating the task.>

<Argument handling: `$ARGUMENTS` if provided; otherwise ask for X.>

<What to do: load a skill, run a subagent, or perform the step in-line.>

<Output contract: what the user receives. Side-effect declaration if any.>
```

Field rules (synthesis of C2/C3/C6/C9/C11):

1. **`description`** ≤60 chars where possible (Claude `/help` truncates; OpenCode TUI shows it inline). Imperative or noun phrase; no trailing period.
2. **`argument-hint`** uses `[optional]` and `<required>` shapes. Show the minimum a user must type. Keep ≤30 chars.
3. **Body** opens with an imperative task statement, not a persona. Persona belongs in the agent prompt (C18). Where a command binds an agent (OpenCode `agent:`, Claude `@agent`), the agent's prompt supplies the persona; the command must not repeat it.
4. **Single responsibility.** One verb. If a command has two modes, either pass the mode as `$1` or split into two commands (C2 best practices).
5. **Show, don't tell** for output contracts. Templates, tables, and fenced examples beat prose ("Return 50-100 lines as a table with these columns…").
6. **Side effects declared.** If the command writes files, hits the network, or runs Bash, say so and list paths/commands. Pair with `allowed-tools: Bash(cmd:*)` on Claude Code.

### 2.5 Anti-patterns (synthesis)

- Persona in the command body (C2; persona lives in the agent prompt).
- Repeating doctrine the bound skill already owns (a shim must not duplicate skill content).
- Bare `$1` in shims targeting Claude Code (see §2.3).
- `model:` set without checking compatibility with OpenCode 0.6.4 and earlier (C8) - the conversation model wins on those builds, so do not rely on it for correctness; treat it as a hint.
- `allowed-tools: "*"` or `Bash` without a filter (C3 explicit warning).
- Long bodies that re-derive routing or response contract that `delegate-task` already owns (C17).
- Time-sensitive text (dates, model IDs that drift). Pin via `model:` where the platform supports it, not in prose.

## 3. Token-efficient command patterns

Baseline: `TOKEN-EFFICIENT-LOOP.md` (C17). The cache-friendly prefix rule and verbatim-relay rule apply unchanged. Two extra command-specific patterns:

### 3.1 Shim vs monolith

A **shim** is a 3-8 line command body that delegates to a skill (or to `delegate-task` plus a target agent). It carries no doctrine. The shim's only job is to capture arguments, name the flow, and load the skill. Cost on each invocation: ~60-120 tokens for the body plus the skill description in the listing; skill body loads on demand.

A **monolith** is a command body that carries the full doctrine inline. Cost on each invocation: the entire body, every turn the command runs. Drift cost: every doctrine change must be made in every monolith body.

| Shape | When appropriate | Indicative length |
|---|---|---|
| Shim | Doctrine is reusable, has both create/update or multiple verbs, or already lives in a skill | 3-8 lines body, 60-120 tokens |
| Self-contained micro-command | One verb, no shared doctrine, no shared format (`/ack`, `/botsnack`, `/ready`) | 1-3 lines body, 20-60 tokens |
| Self-contained command with format | Single verb but the output format is non-trivial and not reused (`/orientate`, `/handover`, `/create-conventional-commit`) | 30-80 lines body, 400-900 tokens |
| Monolith | None recommended. Treat as drift in waiting. | n/a |

Decision rule: if a command would copy ≥30% of its body from another command, the shared part belongs in a skill and both commands become shims.

### 3.2 Length bands (recommendations)

| Class | Target | Hard cap |
|---|---|---|
| Pure shim (loads a skill) | 4-6 lines body | 10 lines |
| Trivial standalone (no format) | 1-2 lines | 3 lines |
| Standalone with output format | 30-60 lines | 80 lines |
| `description.txt` | ≤50 chars | 60 chars (Claude `/help` truncates) |
| `argument-hint` | ≤25 chars | 30 chars |
| `description` + `argument-hint` combined | n/a | Aim for ≤80 chars; OpenCode and Pi listings narrow on small terminals |

### 3.3 Prompt-cache considerations

Claude and OpenAI both cache the static prefix up to a breakpoint (C17 §"Authoritative guidance"). Slash-command bodies sit **after** the system prompt and tool list, so a command body is rarely a cache breakpoint by itself, but it ends up in the cached prefix once the conversation continues past the first turn. Two implications:

1. **Stability matters more than length.** A 6-line shim that is the same shape across all six Rosey shims (`Load X. Argument: $1. Apply X end-to-end. Do not duplicate.`) caches well because the prefix structure is identical except for the skill name.
2. **Avoid embedding volatile data** (timestamps, session IDs, agent registry snippets) in command bodies. Volatile data after the first cache breakpoint forces re-evaluation. Generated content (e.g. the `meet-the-agents`→`delegate-task` replacement) belongs in a skill body that loads on demand, not in command prefixes.

The shim/monolith trade-off therefore has a secondary cache win: shims keep the active prefix small even when several commands run in one session.

## 4. Vendor portability matrix (frontmatter + repo header files)

This repo composes platform headers from per-command files. `compose.nix` (lines 320-356) reads:

- `prompt.md` - the body (mandatory)
- `description.txt` - injected as `description: "<text>"` into Claude/OpenCode/Codex headers; for Pi it becomes `description: <json>` at the top of the frontmatter
- `header.claude.yaml` - extra fields for Claude (`argument-hint`, `model`, `allowed-tools`, `disable-model-invocation`)
- `header.opencode.yaml` - extra fields for OpenCode (`agent`, `model`, `subtask`); typically just `agent: <name>`
- `header.pi.yaml` - extra fields for Pi (`argument-hint` only in current usage)
- Codex is not currently emitted by this repo's `compose.nix` for command output (the repo targets Claude/OpenCode/Pi for commands; Codex is reached via skills).

| Per-command file | Owned by | Required? | Typical content |
|---|---|---|---|
| `prompt.md` | always | Yes | Body of the command. Pi+OpenCode+Claude share it; Claude with an agent binding prepends `@<agent>` (compose.nix L351-353). |
| `description.txt` | always | Yes | One-line label. Trailing emoji conventional in this repo. Injected verbatim into the YAML `description` field. |
| `header.claude.yaml` | always (even if empty) | Yes (compose.nix reads with `readFile`, not optional) | `argument-hint:` (quoted), `model:`, optionally `allowed-tools:`, `use-task: true` for Task-tool dispatch. |
| `header.opencode.yaml` | always | Yes | `agent: <name>` to bind to a sub-agent; otherwise empty. `subtask: true` if the command should run in a fresh sub-session. |
| `header.pi.yaml` | optional (`readOptionalFile`) | No | `argument-hint:` only - Pi has no `model`, `agent`, or `allowed-tools` at the prompt-template layer. |

The matrix below maps fields to header files for `write-command` authors:

| Field | Where it lives in this repo | Claude | OpenCode | Pi | Codex (if revived) |
|---|---|---|---|---|---|
| description | `description.txt` | injected | injected | injected | n/a |
| argument-hint | `header.{claude,pi}.yaml` | yes | not used; OpenCode infers from `$N`/`$ARGUMENTS` in body | yes | yes |
| model | `header.claude.yaml` (and `header.opencode.yaml` if desired) | yes | yes (≥0.7) | n/a | n/a |
| agent binding | `header.opencode.yaml: agent:` and (Claude) `@agent` body prepend | implicit via `@agent` | yes | n/a | n/a |
| allowed-tools | `header.claude.yaml` | yes | n/a | n/a | n/a |
| subtask / fresh context | `header.opencode.yaml: subtask: true` | n/a | yes | implicit (Pi extension prelude in `default.nix`) | n/a |
| disable-model-invocation | `header.claude.yaml` | yes | n/a | n/a | n/a |
| use-task | `header.claude.yaml` (custom this repo) | rewrites body to "Use the Task tool…" | n/a | n/a | n/a |

OpenCode's `header.opencode.yaml` may be empty for standalone commands that need no agent binding; the existing `commands/ack/header.opencode.yaml` is empty and compose still reads it. Pi's header is the only optional one.

## 5. Gap analysis: existing Rosey shims

All six shims share an identical structure (`description.txt`, `header.claude.yaml`, `header.opencode.yaml`, `header.pi.yaml`, `prompt.md`). Verdicts: **keep**, **fix header**, **fix argument-hint**, **rewrite**, **after `write-command` lands**.

| Shim | Description | Claude model | argument-hint | Body shape | Verdict | Notes |
|---|---|---|---|---|---|---|
| `create-skill` | `Create Skill 🧩` | `opus` | `[skill-name]` | 6 lines, loads `write-skill`, uses `$1` | **keep**; `/update-command` pass to swap `$1`→`$ARGUMENTS` | Body says "Skill name argument: $1." On Claude Code this either reads as the second positional arg or empty; on Pi/OpenCode it works. Same `$1` issue across all six shims. |
| `update-skill` | `Update Skill ⚡` | `opus` | `<skill-path>` | 6 lines, loads `write-skill` update flow | **keep**; same `$1`→`$ARGUMENTS` pass | Inconsistent angle bracket: `<skill-path>` reads as required but the shim falls back to "ask if blank", so the hint overstates required-ness. Match Claude convention `[skill-path]` for optional. |
| `create-agents-md` | `Create AGENTS.md 🤖` | `opus` | `[file]` | 6 lines, loads `write-agents-md` | **keep**; `$1`→`$ARGUMENTS` | `[file]` is fine. |
| `update-agents-md` | `Update AGENTS.md 🧠` | `sonnet` | `[file]` | 6 lines, loads `write-agents-md` update/consolidate | **keep**; `$1`→`$ARGUMENTS` | Model differs from `create-agents-md` (sonnet vs opus). Justified by C17 (mid-tier for structured maintenance). |
| `create-assistant` | `Create AI Assistant ✨` | `opus` | `[agent-name]` | 6 lines, loads `write-assistant` | **keep**; `$1`→`$ARGUMENTS` | |
| `update-assistant` | `Update AI Assistant ⚡` | `sonnet` | `<agent-prompt>` | 6 lines, loads `write-assistant` update | **keep**; `<agent-prompt>` → `[agent-prompt]`; `$1`→`$ARGUMENTS` | Same overstated-required hint as `update-skill`. |

Common drift across the six:

- **`$1` portability hazard** (§2.3). Affects all six. Low practical user impact today because Rosey shims are mostly run from OpenCode/Pi, but `write-command` should standardise on `$ARGUMENTS` for shims that take exactly one free-form arg.
- **Angle-bracket vs square-bracket hint convention.** Anthropic's own examples (C3) use `[arg-name]` for both required and optional. The repo mixes `<…>` (required-ish) and `[…]` (optional). Pick one.
- **Trailing emoji in `description.txt`.** Charming and consistent across the repo; harmless. Leave alone.
- **`header.opencode.yaml` only contains `agent: rosey`.** Consistent. Good.
- **Model selection inconsistency between create/update.** Create uses `opus` for the heavier authoring work, update uses `sonnet` for surgical edits. This matches §3 in `PROMPT-WRITING.md` and is defensible; document the rule in `write-command` rather than touching the existing shims.

None of the six bodies needs a rewrite. All six benefit from a single `/update-command` pass once the new skill exists.

## 6. Gap analysis: standalone commands and `handover`

| Command | Headers present | argument-hint | Body shape | Verdict | Notes |
|---|---|---|---|---|---|
| `handover` (agent-scoped, Rosey) | claude, opencode (no pi) | none | ~55 lines, full doctrine inline (sections table, examples, constraints) | **rewrite as shim once `write-handover` or `write-command` covers it**; or treat as a standalone with format and keep as-is | Best candidate for skill extraction. Sections table + 800-2000 word target + marker conventions are all reusable doctrine. Currently fine for a single command; flag for future split if a second handover-like command appears. Missing `header.pi.yaml` means no `argument-hint` is shown in Pi completion, but the command takes no positional arg, so harmless. |
| `ack` | claude, opencode (empty), pi | `[phase]` | 1 line: `$ARGUMENTS Assess and acknowledge my message, then yield your turn.` | **keep** | Canonical micro-command shape. Uses `$ARGUMENTS` correctly. |
| `botsnack` | claude (empty), opencode (empty) | none | 2 lines, no args | **keep**; add `header.pi.yaml` (empty) for consistency? Optional. | Pure ack-style affordance. No args, so no hint. |
| `collaborate` | claude, opencode (empty), pi | `[implementation-plan-path]` | 1 line: `Read $1 and let me know when you are ready to collaborate.` | **fix `$1`→`$ARGUMENTS`** | Same `$1` hazard as the shims. Single-arg command; `$ARGUMENTS` is the correct portable choice. |
| `orientate` | claude (model: haiku), opencode (empty) | none | ~45 lines, sections table, example, constraints | **keep**; consider `header.pi.yaml` add for symmetry | Standalone-with-format - matches the §3.2 band (30-80 lines). Model pinned to haiku for cost; reasonable for a fact-finding command. |
| `ready` | claude, opencode (empty), pi | `[topic]` | 1 line: `$ARGUMENTS Don't do any research, …` | **keep** | Correct use of `$ARGUMENTS`. |

Cross-cutting observations:

- **`header.pi.yaml` is missing from `botsnack`, `handover`, and `orientate`.** All three take no arguments, so the omission is functionally correct (`argument-hint` is the only Pi-relevant field). Add empty files only if the repo wants strict file-set uniformity; not a correctness fix.
- **`collaborate` is the only standalone with the `$1` hazard.** Fix in the same `/update-command` pass that handles the shims.
- **`handover` carries inline doctrine that could live in a future skill** but does not duplicate any existing skill today, so it is **out of scope** for `write-command` unless a second handover-like command appears.
- **`orientate` overlaps `write-agents-md` in spirit** (both inspect a repo to produce a summary) but the output formats are different and `orientate` runs early-session before AGENTS.md exists. Keep separate.

## 7. Proposed shared-skill scope: `write-command`

**Path:** `home-manager/_mixins/agentic/assistants/skills/write-command/SKILL.md`

**Frontmatter (draft):**

```yaml
---
name: write-command
description: Use when creating, updating, or reviewing a slash-command prompt - shims that delegate to a skill or agent, standalone commands with an inline output format, and the description/argument-hint/model headers per provider. Covers Claude Code custom commands and the merged skill-as-command format, OpenCode commands, Pi prompt templates, and the legacy Codex `/prompts:` route. Use even if the user only says "slash command", "prompt template", "command shim", or names the artefact by path.
---
```

**What the skill owns (body, target ≤300 lines):**

1. Decision rules: shim vs standalone vs standalone-with-format vs split-into-two. Use the §3.1 decision rule and length bands.
2. The portable structure template from §2.4.
3. Field-by-field reference for `description`, `argument-hint`, `model`, `allowed-tools`, `agent`, `subtask`, `disable-model-invocation`, `use-task` (this repo's own header field).
4. Argument-passing rules: when to use `$ARGUMENTS`, when `$1..$9` is safe (Pi/OpenCode/Codex only), the cross-platform `$1` hazard from §2.3, and the `argument-hint` conventions (`[optional]` and `<required>`, ≤25 chars).
5. Per-provider file matrix from §4: which header files exist, which are optional, what each one accepts.
6. The repo conventions: `description.txt` is the one-line label with optional trailing emoji; agent binding is `header.opencode.yaml: agent:` + (Claude) `@<agent>` body prepend that `compose.nix` does automatically.
7. Side-effect declaration rules: any Bash needs `allowed-tools: Bash(cmd:*)` on Claude; declare paths the command writes.
8. Anti-patterns from §2.5.
9. Update flow: diagnose, surgical edits, preserve `argument-hint` and `description.txt` unless they're wrong, emit changelog (Removed/Preserved/Added). Same shape as `write-skill` / `write-assistant`.
10. Output: edited or new files (`prompt.md`, `description.txt`, `header.*.yaml`) plus a short changelog.

**What stays in the shims (`/create-command`, `/update-command`):**

Each shim is 4-6 lines and does only: capture `$ARGUMENTS`, name the flow, load `write-command`. Mirrors the existing `create-skill` shim shape exactly.

**References (drafts; ≤100 lines each):**

- `references/portability.md` - the per-platform field table from §4, plus the `$1` hazard call-out.
- `references/templates.md` - filled examples: (a) a pure shim, (b) a trivial standalone, (c) a standalone with format. One per shape.
- `references/repo-conventions.md` - this repo's specific composition (`compose.nix`, header files, `@agent` prepend, `use-task`, OpenCode `init` override pattern from `opencode/default.nix` lines 110-120).

**Cross-links:**

- `write-command` ↔ `write-skill`: when a command is best expressed as a skill (e.g. should be auto-invokable on description), point at `write-skill`.
- `write-command` ↔ `write-assistant`: persona belongs in the agent prompt; commands that bind an agent should not duplicate.
- `write-command` ↔ `delegate-task`: commands that fan out work should reference `delegate-task` rather than re-encoding routing.

**Out-of-scope for the skill:**

- Routing doctrine (lives in `delegate-task`, C17).
- Response contract / relay policy (lives in `delegate-task`, C17).
- Agent persona (`write-assistant`).
- Project memory (`write-agents-md`).
- Reusable knowledge for the model itself (`write-skill`).

## 8. Proposed `/create-command` and `/update-command` shim contracts

### 8.1 `commands/create-command/`

**`description.txt`**

```text
Create Slash Command 🪄
```

**`header.claude.yaml`**

```yaml
argument-hint: "[command-name]"
model: opus
```

**`header.opencode.yaml`**

```yaml
agent: rosey
```

**`header.pi.yaml`**

```yaml
argument-hint: "[command-name]"
```

**`prompt.md`** (target 5 lines)

```markdown
## Create Slash Command

Load the `write-command` skill and run its **create** flow.

Command name argument: $ARGUMENTS. Use it if provided; otherwise ask for the name, the target verb, and which provider headers are needed.

Apply `write-command` end-to-end: shape decision, portable structure, headers per provider, argument-hint, side-effect declaration. Do not duplicate that guidance here.
```

### 8.2 `commands/update-command/`

**`description.txt`**

```text
Update Slash Command ⚡
```

**`header.claude.yaml`**

```yaml
argument-hint: "[command-path]"
model: sonnet
```

**`header.opencode.yaml`**

```yaml
agent: rosey
```

**`header.pi.yaml`**

```yaml
argument-hint: "[command-path]"
```

**`prompt.md`** (target 5 lines)

```markdown
## Update Slash Command

Load the `write-command` skill and run its **update** flow on the target.

Command path argument: $ARGUMENTS. If blank, ask for the command directory or `prompt.md` path.

Apply `write-command`: diagnose body shape, headers per provider, argument-hint, argument substitution (`$ARGUMENTS` vs `$1`), and side-effect declaration; preserve `description.txt` unless wrong; emit the changed files plus a short changelog. Do not duplicate that guidance here.
```

Notes on the contract choices:

- Both shims use `$ARGUMENTS` rather than `$1`, fixing the Claude Code hazard up front (§2.3). The skill will instruct authors to do the same in new shims and to migrate the existing six on the next `/update-command` pass.
- `model: opus` on create matches `create-assistant`/`create-skill`; `model: sonnet` on update matches `update-assistant`/`update-agents-md`. Consistency with the existing Rosey command pairs is more valuable than a small token saving.
- `argument-hint` uses `[…]` (optional) on both; the shim asks for the value if missing. This matches Anthropic's own examples (C3) and avoids the overstated-required pattern in `update-skill`/`update-assistant`.
- `header.opencode.yaml: agent: rosey` binds the command to Rosey on OpenCode; on Claude Code `compose.nix` prepends `@rosey` automatically (L351-353); on Pi the Rosey-scoped command path makes the routing implicit.

## 9. Recommendations

Ordered by leverage. Sizes: S (≤1h), M (half-day), L (full day or more).

1. **(L) Author `write-command/SKILL.md` and three references.** Owns command-authoring doctrine end-to-end: shapes, headers, placeholders, anti-patterns, the `$1` hazard, repo composition. Cites C1-C14.
   *Rejected alternative:* fold command doctrine into `write-skill` because Claude Code is merging commands into skills (C4). Rejected because OpenCode, Pi, and legacy Codex still treat slash commands as a distinct artefact with their own placeholder rules; one mega-skill bloats and obscures.

2. **(S) Add `commands/create-command/` and `commands/update-command/` shims under `agents/rosey/commands/`.** Use the contracts in §8. Each shim is one `prompt.md`, one `description.txt`, three `header.*.yaml` files. Standardise on `$ARGUMENTS`.
   *Rejected alternative:* make a single `/command` slash with a verb argument (`create|update <path>`). Rejected for consistency with the existing six Rosey pairs - splitting verbs into distinct commands matches the established pattern and gives clearer autocomplete.

3. **(S) `/update-command` pass over the six existing Rosey shims.** Swap `$1`→`$ARGUMENTS`. Normalise `update-skill`/`update-assistant` `argument-hint` from `<…>` to `[…]`. No body rewrites needed. Run once `write-command` lands.

4. **(S) `/update-command` pass over `collaborate`.** Swap `$1`→`$ARGUMENTS`. One-line change.

5. **(S) Update Rosey's `prompt.md` to mention `write-command` alongside the other three writing skills.** Same edit shape as the previous additions of `write-skill` / `write-agents-md` / `write-assistant`. Out of scope for the deliverable; flagged for the follow-up.

6. **(M) Audit `handover` against `write-command`.** Probably stays as a standalone-with-format (length band §3.2); only refactor if a sibling handover-like command appears.

7. **(S) Add a `references/repo-conventions.md` snippet covering the OpenCode `init` override pattern** (`opencode/default.nix` L110-120). Future authors should know that overriding a built-in like `/init` involves a one-line edit in `opencode/default.nix`, not just adding files under `commands/`.

8. **(S) Decide whether to add empty `header.pi.yaml` files to `botsnack`, `handover`, `orientate` for file-set uniformity.** Either decision is defensible; default to **not** adding them - the file is optional in `compose.nix` and adding empties just adds noise.

Rejected at the architecture level:

- **Replace all commands with skills.** Anthropic is merging them (C4) but Pi and OpenCode keep them separate, and the repo's `compose.nix` already discriminates. Pre-empting a partial vendor merge would be over-fitting.
- **Generate command bodies from `compose.nix` (like `delegate-task`).** Skills benefit from generation because the agent registry is volatile; command bodies are stable and tiny. No leverage.

## 10. Open questions / blockers

1. **Claude Code legacy command `$1` semantics.** C1 and C2 do not document positional placeholders for the legacy `.claude/commands/<name>.md` format; C4 documents `$N` as 0-indexed for the new merged skill-as-command format. The six existing shims currently use `$1` and have been working; whether Claude Code's legacy parser silently expands `$1` to the first positional arg (matching Pi/OpenCode), expands it empty, or expands it as `$ARGUMENTS[1]` (i.e. second arg) is not clear from the public docs. Recommended: standardise on `$ARGUMENTS` and avoid the question.
2. **OpenCode `model:` honouring.** C8 confirms `model:` was ignored on 0.6.4 and below; the fix shipped in a later release. The repo should not rely on per-command model overrides as a correctness mechanism on OpenCode. Document as a hint, not a guarantee.
3. **Codex coverage.** Custom prompts are deprecated (C9). Worth deciding whether `write-command` covers Codex at all, or punts to `write-skill` for Codex authors. Recommendation: a single short section explaining the legacy `/prompts:` route + an explicit pointer to `write-skill` for new Codex work.
4. **Cursor reach.** C15 confirms Cursor supports a related Markdown-with-frontmatter shape but no positional args. Cover in `references/portability.md` only if the repo intends to publish Cursor commands; otherwise out of scope.
5. **`use-task` field naming.** `compose.nix` L342 detects `use-task: true` in the Claude header and rewrites the body to "Use the Task tool to launch the `<agent>` agent for the following task:". This is a repo-local convention not documented anywhere user-facing. `write-command` should document it; consider whether to rename to something less generic (e.g. `launch-via-task: true`) - out of scope for this brief.
6. **Sub-task default on OpenCode.** OpenCode's docs say "If this is a subagent the command will trigger a subagent invocation by default" (C6). All six Rosey shims bind `agent: rosey`. Whether the current OpenCode build runs them as subtasks by default or requires explicit `subtask: true` is version-dependent. Confirm against the installed OpenCode before guidance hardens.

## 11. Out of scope

- Rosey's own `prompt.md` (touched only in recommendation 5, follow-up task).
- Adding empty `header.pi.yaml` files to existing standalone commands without arguments.
- Refactoring `handover` into a skill (would need a sibling command to justify).
- Generating commands from `compose.nix`.
- Cursor and Aider delivery targets (Cursor only documented if the repo decides to publish; Aider is not extensible at the prompt-file layer).
- Migrating Codex skill / prompt setup; covered by `write-skill` for new work.
- Reworking `model:` selections across the existing command estate.
- The `delegate-task` skill, response contract, and relay policy (owned by `TOKEN-EFFICIENT-LOOP.md`).
