
# Write Command

Author and maintain commands across Claude Code, OpenCode, Pi prompt templates, and Codex command-derived skills. One artefact, two flows: create from scratch or update in place.

## Decide first

- **Long command choice.** Before editing, when a command is likely to exceed 100 lines, pause and ask one focused question: keep it inline, or use a thin command plus a skill for reusable guidance? Recommend based on reuse, not length alone. Keep command-specific guidance inline; recommend a skill when the guidance has independent reuse. Honour the user's choice.
- **Shim** vs **standalone** vs **standalone-with-format**. A shim is a 3-8 line body that names the flow and loads a skill. A standalone command carries its own one-verb body. Add an inline output format only when it is non-trivial and not reused.
- **Single-purpose output-format commands stay standalone.** Do not refactor a working standalone-with-format command into a shim speculatively. Recommend extraction when a sibling command would share ≥30% of the body or the guidance has independent reuse.
- **Command** vs **skill**. Commands are user-invoked and deterministic; skills are description-triggered and reusable. If the workflow needs an argument and a fixed name, use a command; pair it with a skill when the guidance is reusable. If the workflow has no argument and should auto-load on description, build a skill instead.
- **Shared doctrine extraction.** If a body copies ≥30% from another command, recommend lifting the shared part into a skill and reducing both commands to shims. This advice does not override an explicit choice to keep the command inline.

Length bands:

| Form                           | Target lines | Limit or decision |
| ------------------------------ | ------------ | ----------------- |
| Shim (loads a skill)           | 4-6          | Hard cap: 10      |
| Trivial standalone (no format) | 1-2          | Hard cap: 3       |
| Standalone with output format  | 30-60        | Ask above 100     |

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
- Vendor-specific fields (`allowed-tools`, `subtask`, and `disable-model-invocation`) belong in provider or routing tables in `header.toml`; see `references/portability.md`.

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

Use `$ARGUMENTS` for a shared command that takes one free-form argument. Claude Code, OpenCode, and Pi substitute it. Codex command-derived skills receive the user's accompanying text without template substitution. Treat `$ARGUMENTS` there as that text, not as an expanded variable.

`$1..$9` is **not** portable. Pi, OpenCode, and legacy Codex custom prompts use 1-based positions. Claude Code skills use 0-based positions. Legacy Claude Code commands do not document positional placeholders. Codex command-derived skills do not substitute them. For shared bodies with existing positions, define their meaning and map the supplied text explicitly on Codex.

`$@`, `${@:N}`, `${@:N:L}` are Pi-only. Keep them out of portable shims.

## Repo composition

This repo reads one `header.toml` and one `prompt.md` per command. Keep the body free of frontmatter.

```toml
[common]
description = "Create Skill 🧩"
argument-hint = "[skill-name]"

[compose]
agent = "rosey"
```

Use `[common]` for the description and a hint shared by Claude Code, OpenCode, and Pi. Preserve existing provider-specific omissions under `[claude]`, `[opencode]`, or `[pi]`.

Keep native non-model fields in provider tables. Put model and effort overrides only under `[routing.<provider>]`. Pi agent routing uses `[routing.pi.<inference-provider>]`.

Use `[compose] agent` for the repository agent binding. Set `[compose.claude] use-task = true` for a Task wrapper. Set `[compose.codex] spawn-agent = false` for same-context execution. Omitted controls preserve the composer defaults.

Names derive from directories. Missing provider tables mean no overrides, not disabled output. TOML has no null. Omit fields to inherit defaults.

The composer discovers commands by directory. Retired provider headers are removed. Retired `description.txt` files are not inputs. Keep them until the user authorises removal.

Codex receives each command as a manual-only command-derived skill, invoked by the user as `$name`. The composer owns `agents/openai.yaml` with `policy.allow_implicit_invocation: false` for every command, including secret bodies. Do not add this policy to shared frontmatter or ordinary reusable skills.

## Nested workflows

Manual-only controls command selection, not file access or workflow reuse within an authorised task. A `$child` token inside loaded Codex instructions does not recursively load that command.

- Resolve the named workflow from the available skill catalogue, configured skill roots, or repository command source. Read its instructions before dependent work.
- Supply the exact arguments, existing authority, output contract, and return point. A nested read grants no new mutation authority.
- For same-context work, follow the workflow body without its generated agent-launch wrapper. Keep staging and commits in their declared owning context.
- For specialist work, the top-level orchestrator dispatches the workflow body directly with a bounded packet. Workers return directly and launch no agents.
- Preserve user-facing `$name` examples on Codex and `/name` examples on slash-command runtimes. Do not use prefix conversion as workflow composition.

## Command table

`home-manager/_mixins/agentic/assistants/README.md` documents every command. Update it in the same change: a new command gets a row, a renamed command gets its row renamed, a command whose purpose changes gets its purpose line rewritten.

- Pick the table first. `### Standalone Commands` covers commands under `commands/` with no agent binding; each `### <Agent> - <Role>` section under `## Agents` carries its own table for the commands under `agents/<agent>/commands/`.
- `### Standalone Commands` rows are alphabetical by command name. An agent table keeps its existing grouping.
- The purpose line says what the command does for the user, not which skill it loads. "Rewrite the previous response concisely", not "Load the `communication-rules` skill".

## Per-provider field matrix

When a command accepts arguments, put a shared `argument-hint` in `[common]`. Claude Code, OpenCode, and Pi all display it; do not skip a provider.

See `references/portability.md` for the full table. Headlines:

- **Claude Code:** `description`, `argument-hint`, `model`, `allowed-tools`, `disable-model-invocation`. Legacy `.claude/commands/<name>.md` and the new skill-as-command format both yield `/<name>`.
- **OpenCode:** `description`, `agent`, `model`, `subtask`. Per-command `model` was ignored on 0.6.4 and below; treat it as a hint, not a guarantee. `subtask` controls fresh-context execution - see below.
- **Pi:** `description`, `argument-hint`. Model and routing live in the agent layer, not the prompt template.
- **Codex:** generated `SKILL.md` plus `agents/openai.yaml` with `policy.allow_implicit_invocation: false`. Users invoke `$name`. CLI 0.117.0 removed legacy custom prompts and their placeholder substitution.

## OpenCode `subtask`

OpenCode's slash commands invoke in the caller's session by default. The exception is when `agent:` binds to a subagent: that binding alone triggers a subagent invocation, so the command body runs in a fresh context owned by the named agent. `subtask: true` **forces** subagent invocation even when the bound agent is `mode: primary`, so the body still runs in a fresh subagent context without polluting the caller's session. `subtask: false` explicitly opts out and keeps execution in the caller's session even if the bound agent is a subagent (honoured by spec; some 2026-era builds ignore it - see sst/opencode#10431).

Repo convention for Rosey's shims: **omit `subtask`**. The `agent: <name>` binding already owns the context boundary, and OpenCode's default subagent invocation gives the fresh context for free. Set `subtask: true` only on a standalone command that needs a fresh context without changing the active agent (e.g. a `/review`-style command bound to a primary agent that you want isolated from the main thread).

## Model selection

In this repo:

- Command-level pins are rare. Only `draft-commit-message` and `draft-pr-message` set `model: sonnet` in Claude Code. Every standalone command, including `make-pr`, omits `model` and inherits the root session model.
- Pin a model on a new command only when both hold: the work needs a specific tier regardless of the caller's session, and the command can run detached from its agent. Otherwise leave it out.
- OpenCode routing tables omit `model` so the user's session model wins. Per-command `model` was ignored on OpenCode 0.6.4 and below; treat it as a hint, not a guarantee.
- Pi has no model field at the prompt-template layer; model and routing live on the agent.

## Side-effect declaration

If the body writes files, runs Bash, or hits the network, say so and list paths or commands. On Claude Code, pair with `allowed-tools: Bash(<cmd>:*)`; never use `allowed-tools: "*"` or unfiltered `Bash`. Hooks at `UserPromptExpansion` can inject context or block expansion; declare any expected hook interaction.

## Anti-patterns

- Persona in the command body. Persona lives in the agent prompt.
- Repeating doctrine the bound skill already owns.
- Bare `$1` in shims targeting Claude Code (use `$ARGUMENTS`).
- `allowed-tools` left as `"*"` or bare `Bash`.
- Long bodies that re-derive routing or response contract owned by `delegate-task`.
- Time-sensitive text (dates, model IDs) in the body. Pin via `[routing.<provider>] model` instead.
- Embedding generated content (e.g. agent registry snippets) into a command prefix - the volatile data breaks the prompt cache. Put it in a skill that loads on demand.
- Targeting Codex via legacy `/prompts:` for new work. Use the command composer for commands and `write-skill` for reusable skills.

## Update flow

1. Read `prompt.md` and `header.toml`.
2. Identify the form band (shim / standalone / standalone-with-format). Enforce the shim and trivial caps; apply the long command choice before editing a standalone-with-format command.
3. Diagnose: argument substitution (`$ARGUMENTS` vs `$1`), `argument-hint` bracket convention, persona leakage, missing or stale `description`, model mismatch with sibling commands, missing side-effect declaration, missing or stale README row.
4. Edit narrowly. Preserve `[common] description` and `argument-hint` unless they are wrong. Do not rewrite a working body.
5. If a shim and an existing skill both grew the same doctrine, cut the shim back to the skill body's surface.
6. Emit changed files plus a short changelog: `Changed`, `Rationale`.

## Output

When invoked to **create**, produce `prompt.md` and `header.toml` in fenced blocks ready to save at the correct path.

When invoked to **update**, produce only the changed files plus the changelog. Preserve unchanged sections verbatim.

If invoked as a sub-agent for routing reasons, follow the response contract from `delegate-task`: start non-artefact work with `Answer:`; return raw artefacts only when the artefact is the deliverable.

## References

- `references/portability.md` - per-platform frontmatter and placeholder matrix; the `$1` hazard.
- `references/templates.md` - filled examples for a shim, a trivial standalone, and a standalone-with-format command.
- `references/repo-conventions.md` - this repo's `compose.nix` composition, agent prepend, `use-task`, and the OpenCode `/init` override pattern.
