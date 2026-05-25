---
name: write-command
description: Use when creating, updating, or reviewing a slash command - shims that delegate to a skill or agent, standalone commands with an inline output format, and the `description` / `argument-hint` / `model` headers per provider. Covers Claude Code custom commands and the merged skill-as-command format, OpenCode commands, Pi prompt templates, and the legacy Codex `/prompts:` route. Use even if the user only says "slash command", "prompt template", "command shim", "create-command", or names the artefact by path.
---

# Write Command

Author and maintain slash commands across Claude Code, OpenCode, Pi prompt templates, and legacy Codex custom prompts. One artefact, two flows: create from scratch or update in place.

## Decide first

- **Shim** vs **standalone** vs **standalone-with-format** vs **split into two**. A shim is a 3-8 line body that names the flow and loads a skill. A standalone command carries its own one-verb body. Add an inline output format only when the shape is non-trivial and not reused.
- **Single-purpose output-format commands stay standalone.** Do not refactor a working standalone-with-format command into a shim speculatively; only convert once a sibling command appears that would share ≥30% of the body.
- **Command** vs **skill**. Commands are user-invoked and deterministic; skills are description-triggered and reusable. If the workflow needs an argument and a fixed name, build a shim that loads a skill. If the workflow has no argument and should auto-load on description, build a skill instead.
- **Shared doctrine extraction.** If a body copies ≥30% from another command, lift the shared part into a skill and reduce both commands to shims.

Length bands:

| Shape                          | Target lines | Hard cap |
| ------------------------------ | ------------ | -------- |
| Shim (loads a skill)           | 4-6          | 10       |
| Trivial standalone (no format) | 1-2          | 3        |
| Standalone with output format  | 30-60        | 80       |

## Frontmatter (portable, required)

```yaml
---
description: <one-line label shown in completion>
argument-hint: "[optional-arg] <required-arg>"
---
```

Rules:

- `description` ≤60 chars where possible. Imperative or noun phrase. No trailing period. Trailing emoji is fine and conventional in this repo.
- `argument-hint` ≤25 chars. `[arg]` for optional, `<arg>` for required. Anthropic's own examples use `[arg]` for both; if the body falls back to "ask if blank", the argument is optional and the hint must use `[…]`.
- Vendor-specific fields (`model`, `allowed-tools`, `agent`, `subtask`, `disable-model-invocation`, repo-local `use-task` - Claude Code only; rewrites the body to dispatch through the Task tool) belong in the per-platform header files; see `references/portability.md`.

## Body

Imperative, single-responsibility, no persona. Persona lives in the bound agent prompt; the command must not repeat it.

Structure of a shim:

1. Optional `## Title` heading.
2. One imperative sentence naming the flow and the skill to load.
3. One sentence describing argument handling (`$ARGUMENTS` if provided, otherwise ask).
4. One sentence saying "Apply `<skill>` end-to-end" listing the headline phases. Close with "Do not duplicate that guidance here."

Structure of a standalone-with-format command:

1. One imperative purpose sentence.
2. Required handling rules (numeric limits, redaction, paths).
3. Output template (sections table, markers, examples).
4. Constraints (skip rules, exclusions).

## Argument substitution

`$ARGUMENTS` is the only portable choice across Claude Code, OpenCode, Pi, and Codex. Use it for any command that takes a single free-form argument.

`$1..$9` is **not** portable: it is 1-indexed on Pi, OpenCode, and Codex, but the new Claude Code skill-as-command format treats `$N` as `$ARGUMENTS[N]` with **0-based indexing**, and the legacy Claude Code command format does not document positional placeholders at all. Use `$1..$9` only when the command body is consumed exclusively by Pi / OpenCode / Codex and the position-by-position split is essential.

`$@`, `${@:N}`, `${@:N:L}` are Pi-only. Keep them out of portable shims.

## Repo composition

This repo composes platform headers from per-command files. `compose.nix` reads:

| File                   | Required? | Purpose                                                           |
| ---------------------- | --------- | ----------------------------------------------------------------- |
| `prompt.md`            | yes       | Body. Shared across Claude / OpenCode / Pi.                       |
| `description.txt`      | yes       | One-line label, trailing emoji conventional.                      |
| `header.claude.yaml`   | yes       | `argument-hint`, `model`, `allowed-tools`, `use-task`.            |
| `header.opencode.yaml` | yes       | `agent:` binding, optional `model`, optional `subtask: true`.     |
| `header.pi.yaml`       | no        | `argument-hint` only - Pi has no model/agent at the prompt layer. |

`header.claude.yaml` and `header.opencode.yaml` are read with `readFile` and **must exist for every command, even if no per-provider fields are set** - leave them as empty files; omitting them makes Nix evaluation fail. `header.pi.yaml` is genuinely optional (read with `readOptionalFile`) and can be omitted when the command takes no arguments. On Claude Code, an agent binding via `header.opencode.yaml: agent:` causes `compose.nix` to prepend `@<agent>` to the body automatically; do not write `@agent` into `prompt.md`. The repo-local `use-task: true` field in `header.claude.yaml` rewrites the body into "Use the Task tool to launch the `<agent>` agent for the following task: …". `compose.nix` discovers commands by directory; no codegen edits are required when adding a new command.

Skills are not currently emitted as commands by this repo's Codex output; reach Codex via skills instead (see anti-patterns).

## Per-provider field matrix

See `references/portability.md` for the full table. Headlines:

- **Claude Code:** `description`, `argument-hint`, `model`, `allowed-tools`, `disable-model-invocation`. Legacy `.claude/commands/<name>.md` and the new skill-as-command format both yield `/<name>`.
- **OpenCode:** `description`, `agent`, `model`, `subtask`. Per-command `model` was ignored on 0.6.4 and below; treat it as a hint, not a guarantee.
- **Pi:** `description`, `argument-hint`. Model and routing live in the agent layer, not the prompt template.
- **Codex (legacy):** `description`, `argument-hint`, `$ARGUMENTS`, `$1..$9`, `$NAMED`. Custom prompts are deprecated; point new Codex work at `write-skill`.

## Model selection

In this repo:

- Rosey's `create-*` and `update-*` shims pin `model: opus` (Claude Code). Prompt and skill authoring rewards the strongest model for structure, terseness, and cross-platform reasoning; surgical edits benefit from the same judgement as creation.
- Standalone formatting / fact-finding commands may pin `model: haiku` (e.g. `orientate`).
- OpenCode headers omit `model` so the user's session model wins. Per-command `model` was ignored on OpenCode 0.6.4 and below; treat it as a hint, not a guarantee.
- Pi has no model field at the prompt-template layer; model and routing live on the agent.

## Side-effect declaration

If the body writes files, runs Bash, or hits the network, say so and list paths or commands. On Claude Code, pair with `allowed-tools: Bash(<cmd>:*)`; never use `allowed-tools: "*"` or unfiltered `Bash`. Hooks at `UserPromptExpansion` can inject context or block expansion; declare any expected hook interaction.

## Anti-patterns

- Persona in the command body. Persona lives in the agent prompt.
- Repeating doctrine the bound skill already owns.
- Bare `$1` in shims targeting Claude Code (use `$ARGUMENTS`).
- `allowed-tools` left as `"*"` or bare `Bash`.
- Long bodies that re-derive routing or response contract owned by `delegate-task`.
- Time-sensitive text (dates, model IDs) in the body. Pin via `model:` instead.
- Embedding generated content (e.g. agent registry snippets) into a command prefix - the volatile data breaks the prompt cache. Put it in a skill that loads on demand.
- Targeting Codex via `/prompts:` for new work. Build a skill and point at `write-skill`.

## Update flow

1. Read `prompt.md`, `description.txt`, and every `header.*.yaml`.
2. Identify the shape band (shim / standalone / standalone-with-format) and confirm length is within the cap.
3. Diagnose: argument substitution (`$ARGUMENTS` vs `$1`), `argument-hint` bracket convention, persona leakage, missing or stale `description`, model mismatch with sibling commands, missing side-effect declaration.
4. Edit narrowly. Preserve `description.txt` and `argument-hint` unless they are wrong. Do not rewrite a working body.
5. If a shim and an existing skill both grew the same doctrine, cut the shim back to the skill body's surface.
6. Emit changed files plus a short changelog: `Changed`, `Rationale`.

## Output

When invoked to **create**, produce `prompt.md`, `description.txt`, and the three `header.*.yaml` files in fenced blocks ready to save at the correct path.

When invoked to **update**, produce only the changed files plus the changelog. Preserve unchanged sections verbatim.

If invoked as a sub-agent for routing reasons, follow the response contract from `delegate-task`: start non-artefact work with `Answer:`; return raw artefacts only when the artefact is the deliverable.

## References

- `references/portability.md` - per-platform frontmatter and placeholder matrix; the `$1` hazard.
- `references/templates.md` - filled examples for a shim, a trivial standalone, and a standalone-with-format command.
- `references/repo-conventions.md` - this repo's `compose.nix` composition, agent prepend, `use-task`, and the OpenCode `/init` override pattern.
