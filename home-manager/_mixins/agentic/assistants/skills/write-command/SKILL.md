
# Write Command

Author and maintain commands across Claude Code, OpenCode, Pi prompt templates, and Codex command-derived skills. One artefact, two flows: create from scratch or update in place.

## Decide first

- **Caller context** vs **specialist selection**. Set `[compose] caller-context = true` to preserve the caller's role and suppress generated dispatch and persona insertion. The default is `false`, which does not guarantee child execution. This repository setting is not native Pi. It grants no coordinator authority and does not make a parent-linked session top-level.
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

## Generated native frontmatter

The composer generates native frontmatter from `command.toml`. Keep repository Markdown bodies free of frontmatter.

```yaml
---
description: <one-line label shown in completion>
argument-hint: "[optional-arg] <required-arg>"
---
```

Rules:

- `description` ≤60 chars where possible. Imperative or noun phrase. No trailing period. Trailing emoji is fine and conventional in this repo.
- `argument-hint` ≤25 chars. `[arg]` for optional, `<arg>` for required. Anthropic's own examples use `[arg]` for both; if the body falls back to "ask if blank", the argument is optional and the hint must use `[…]`.
- Vendor-specific fields (`allowed-tools`, `subtask`, and `disable-model-invocation`) belong in native provider tables in `command.toml`; see `references/portability.md`.

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

Use the global vocabulary: the coordinator owns planning, dispatch, integration, and assigned inline operations. A worker completes bounded work and never launches agents. The caller invokes a command or follows its body and can be a worker. Parent and child name only the immediate delegation relationship. The command owner maintains the workflow, independent of its location, selected agent, and executor. Do not add ownership metadata. Context is instructions and evidence, not role or authority.

Store every command in `commands/<name>/` with `command.toml` and exactly one `command.md` or `command.sops`. Keep public bodies free of frontmatter. A secret marker names the existing SOPS key, not the body.

```toml
[common]
description = "Create Skill 🧩"
argument-hint = "[skill-name]"

[compose]
agent = "rosey"
```

Use `[common]` for the description and a hint shared by Claude Code, OpenCode, and Pi. Preserve existing provider-specific omissions under `[claude]`, `[opencode]`, or `[pi]`.

Keep native non-model fields in provider tables. Claude Code, Codex, and Pi reject non-empty command routing. Put their routing defaults only in the selected agent's `header.toml`. OpenCode command model metadata remains supported under `[routing.opencode]`.

Set `[compose] agent` explicitly for an agent binding. No directory supplies an inherited agent. Omit `agent` for an unbound command. Shared `caller-context = true` takes precedence over provider launch controls and keeps the caller's context and persona. It suppresses Claude agent/Task wrappers, OpenCode agent binding, Pi launches, and Codex persona/spawn wrappers. OpenCode also receives `subtask: false`.

Agent-bound specialist commands use Claude's Task wrapper by default. Explicit `[compose.claude] use-task = false` selects the inline `@agent` exception without a child launch. `[compose.codex] spawn-agent = false` embeds the agent persona in the caller's context. Neither exception preserves the caller's role through the shared setting.

### Coordinator guidance

Put command-specific packet preparation and continuation instructions in `command.toml`, not in the worker body:

```toml
[compose.coordinator]
before-launch = """
Add the user's exact paths and existing authority to the worker packet.
"""
after-return = """
Ask for consent before the next workflow.
"""
```

Only `before-launch` and `after-return` are valid keys. Both accept strings, including multiline strings. Omitted keys or an omitted table add no guidance. Empty strings are valid. Unknown keys and other value types fail validation.

The composer reads these fields from the command source, regardless of the selected agent. Claude Code, Pi, and Codex launch wrappers place both instructions before `## Task`, outside the worker body and native metadata. `after-return` describes what the coordinator does after the worker returns. These fields are prose, not executable hooks or role grants.

Caller-context execution and per-provider inline modes bypass both fields. Direct workflow body reuse is unchanged. OpenCode native binding cannot run coordinator preparation or continuation steps. Keep required explicit-context checks and watch handover instructions in its shared worker body. Do not add a simulated wrapper.

### Discovery and defaults

Names derive from directories. Missing provider tables mean no overrides, not disabled output. TOML has no null. Omit fields to inherit defaults.

The composer discovers commands only under `commands/<name>/`. Retired provider headers are removed. Retired `description.txt` files are not inputs. Keep them until the user authorises removal.

Codex receives each command as a manual-only command-derived skill, invoked by the user as `$name`. The composer owns `agents/openai.yaml` with `policy.allow_implicit_invocation: false` for every command, including secret bodies. Do not add this policy to shared frontmatter or ordinary reusable skills.

## Nested workflows

Manual-only controls command selection, not file access or workflow reuse within an authorised task. A `$child` token inside loaded Codex instructions does not recursively load that command.

- Resolve the named workflow from the available skill catalogue, configured skill roots, or repository command source. Read its instructions before dependent work.
- Supply the exact arguments, existing authority, output contract, and return point. A nested read grants no new mutation authority.
- For same-context work, follow the workflow body without its generated agent-launch wrapper. Keep staging and commits in their declared owning context.
- Applying a nested workflow inside a worker does not authorise its generated launch wrapper or further delegation.
- For specialist work, the coordinator dispatches the workflow body directly with a bounded packet. Workers return directly and launch no agents.
- Put the worker contract in the child's task, not the parent's launch instructions. Use native tool names in wrappers and generic delegation terms in shared prose.
- Preserve user-facing `$name` examples on Codex and `/name` examples on slash-command runtimes. Do not use prefix conversion as workflow composition.

## Command catalogue

The generated `home-manager/_mixins/agentic/assistants/commands/README.md` lists command metadata and client entry behaviour. A separate agent table lists routing defaults from `header.toml`. The main README links the catalogue and keeps workflow guidance, not duplicate inventories.

- Update `command.toml` when a command's description, binding, or entry behaviour changes.
- Write descriptions that state what the command does for the user, not which skill it loads.
- After command additions, renames, metadata changes, or agent routing changes, run `just update-assistant-catalogue`.
- Run `just check-assistant-catalogue` to check the tracked output. Do not edit generated rows manually.
- Check the associated agent, per-client entry behaviour, routing defaults, and public/secret source classification. Never decrypt bodies for catalogue generation.

## Per-provider field matrix

When a command accepts arguments, put a shared `argument-hint` in `[common]`. Claude Code, OpenCode, and Pi all display it; do not skip a provider.

See `references/portability.md` for the full table. Headlines:

- **Claude Code:** `description`, `argument-hint`, `allowed-tools`, `disable-model-invocation`. Native command `model` exists, but this repository rejects command routing. Legacy `.claude/commands/<name>.md` and the new skill-as-command format both yield `/<name>`.
- **OpenCode:** `description`, `agent`, `model`, `subtask`. Per-command `model` was ignored on 0.6.4 and below; treat it as a hint, not a guarantee. `subtask` controls fresh-context execution - see below.
- **Pi:** `description`, `argument-hint`. Model and routing live in the agent layer, not the prompt template.
- **Codex:** generated `SKILL.md` plus `agents/openai.yaml` with `policy.allow_implicit_invocation: false`. Users invoke `$name`. CLI 0.117.0 removed legacy custom prompts and their placeholder substitution.

## OpenCode `subtask`

OpenCode's slash commands invoke in the caller's session by default. The exception is when `agent:` binds to a subagent: that binding alone triggers a subagent invocation, so the command body runs in a fresh context owned by the named agent. `subtask: true` **forces** subagent invocation even when the bound agent is `mode: primary`, so the body still runs in a fresh subagent context without polluting the caller's session. `subtask: false` explicitly opts out and keeps execution in the caller's session even if the bound agent is a subagent (honoured by spec; some 2026-era builds ignore it - see sst/opencode#10431).

For specialist shims, omit `subtask`. The agent binding already selects a fresh context. To preserve the caller's role, use shared `caller-context = true`. The composer removes the agent binding and forces `subtask: false`. Reserve `subtask: true` for specialist commands that need a fresh context with a primary agent.

## Model selection

In this repo:

- Agent headers are the sole routing default source for Claude Code, Codex, and Pi. Commands and ordinary skills stay model-neutral.
- Caller-context execution never changes the caller's model, whether or not the command has an agent binding. Preserve `compose.caller-context` and provider launch controls.
- Child launches use the selected agent's defaults. Explicit launch-time child model, thinking, or effort overrides remain supported.
- OpenCode agent and command model metadata support is unchanged. Current OpenCode agents and commands omit model pins.
- Pi uses the exact active provider's agent route, or native fallback when that route is absent.

## Side-effect declaration

If the body writes files, runs Bash, or hits the network, say so and list paths or commands. On Claude Code, pair with `allowed-tools: Bash(<cmd>:*)`; never use `allowed-tools: "*"` or unfiltered `Bash`. Hooks at `UserPromptExpansion` can inject context or block expansion; declare any expected hook interaction.

## Anti-patterns

- Persona in the command body. Persona lives in the agent prompt.
- Repeating doctrine the bound skill already owns.
- Bare `$1` in shims targeting Claude Code (use `$ARGUMENTS`).
- `allowed-tools` left as `"*"` or bare `Bash`.
- Long bodies that re-derive routing or response contract owned by `delegate-task`.
- Time-sensitive text (dates, model IDs) in the body. Put routing defaults in the selected agent's header instead.
- Embedding generated content (e.g. agent registry snippets) into a command prefix - the volatile data breaks the prompt cache. Put it in a skill that loads on demand.
- Targeting Codex via legacy `/prompts:` for new work. Use the command composer for commands and `write-skill` for reusable skills.

## Update flow

1. Read `command.toml` and the public `command.md`, or identify the `command.sops` marker without decrypting it.
2. Identify the form band (shim / standalone / standalone-with-format). Enforce the shim and trivial caps; apply the long command choice before editing a standalone-with-format command.
3. Distinguish caller role, maintenance ownership, selected agent, and executor. Check argument substitution (`$ARGUMENTS` vs `$1`) and the `argument-hint` bracket convention. Check persona leakage, stale descriptions, routing defaults, missing side-effect declarations, and catalogue freshness.
4. Edit narrowly. Preserve `[common] description` and `argument-hint` unless they are wrong. Do not rewrite a working body.
5. If a shim and an existing skill both grew the same doctrine, cut the shim back to the skill body's surface.
6. Emit changed files plus a short changelog: `Changed`, `Rationale`.

## Output

When invoked to **create**, produce `command.md` and `command.toml` in fenced blocks ready to save at the correct path.

When invoked to **update**, produce only the changed files plus the changelog. Preserve unchanged sections verbatim.

If invoked as a worker for routing reasons, follow the response contract from `delegate-task`: start non-artefact work with `Answer:`; return raw artefacts only when the artefact is the deliverable.

## References

- `references/portability.md` - per-platform frontmatter and placeholder matrix; the `$1` hazard.
- `references/templates.md` - filled examples for a shim, a trivial standalone, and a standalone-with-format command.
- `references/repo-conventions.md` - this repo's `compose.nix` composition, agent prepend, `use-task`, and the OpenCode `/init` override pattern.
