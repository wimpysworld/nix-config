# Repo conventions

This repo's command estate composes through `home-manager/_mixins/agentic/assistants/compose.nix`. Authors should know the conventions below. Everything else is generic command authoring.

## File set per command

```
commands/<name>/                              (standalone)
agents/<agent>/commands/<name>/               (agent-scoped)
├── prompt.md             body without frontmatter
└── header.toml           shared, provider, composition, and routing metadata
```

`compose.nix` discovers commands by directory listing - no codegen edits when adding a new command.

## Agent prepend on Claude Code

For leaf commands with `[compose] agent = "<name>"`, the composer prepends `@<name>` to the Claude Code body. Do not write `@agent` into `prompt.md`. Shared `root = true` suppresses this prepend and all provider launch wrappers. Root commands retain the caller's context and persona. OpenCode root output omits `agent` and forces `subtask: false`.

## `use-task: true` (repo-local)

For leaf commands, `[compose.claude] use-task = true` rewrites the Claude Code body into:

```
Use the Task tool to launch the <agent> agent for the following task:

<prompt.md body>
```

This dispatches the command through Claude's Task tool instead of the `@agent` prepend. Use sparingly; the prepend pattern is the default.

## OpenCode `/init` override

`home-manager/_mixins/agentic/opencode/default.nix` (around lines 110-120) reads `agents/rosey/commands/create-agents-md/prompt.md` directly and overrides OpenCode's built-in `/init` command with it. If you rename `create-agents-md` or move its `prompt.md`, update that file in the same change. Overriding any other OpenCode built-in (e.g. `/review`) follows the same pattern: one entry in `opencode/default.nix` reading a `prompt.md` from the assistants tree.

## Provider tables

Use `[common] argument-hint` when Claude Code, OpenCode, and Pi share its presence and value. Preserve differing hints in native provider tables.

Missing provider tables mean no overrides, not disabled output. Use `[routing.<provider>]` for model and effort fields. Pi agent pins belong under `[routing.pi.<inference-provider>]`.

Retired provider headers are removed. Retired `description.txt` files remain unconsumed until the user authorises removal.

## Codex output

Codex receives every command as a manual-only command-derived skill. Users invoke `$name`. The composer emits `agents/openai.yaml` with `policy.allow_implicit_invocation: false` for every command, including secret bodies. The command policy is mandatory and does not change ordinary skill policies.

Agent-scoped leaf commands use `spawn_agent` by default. Set `[compose.codex] spawn-agent = false` to embed the owning agent prompt in the caller's context. Shared `root = true` takes precedence and emits neither the agent persona nor the spawn wrapper. For nested workflows, follow the source body directly or dispatch it from the top-level orchestrator. Do not execute a generated launch wrapper inside a worker. Resolve installed instructions through the available catalogue or configured skill roots, not a fixed home path.

Codex does not substitute `$ARGUMENTS` or positional placeholders in these skills. Map the user's accompanying text to the body's declared arguments. New Codex-only reference guidance belongs in a native skill.
