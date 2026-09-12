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

## Claude Code dispatch

For leaf commands with `[compose] agent = "<name>"`, the composer dispatches through Claude's Task tool by default. Omitted `[compose.claude] use-task` means `true`. Explicit `use-task = false` selects the inline `@<name>` prepend without a child launch. Do not write either wrapper into `prompt.md`.

Shared `root = true` suppresses this prepend and all provider launch wrappers. Root commands retain the caller's context and persona. OpenCode root output omits `agent` and forces `subtask: false`.

## Leaf dispatch wrappers

The composer owns launch instructions and the terminal-worker contract. Keep these out of command source bodies. Generated wrappers name the native tool: Claude `Task`, Pi `subagent`, or Codex `spawn_agent`.

The parent supplies a bounded packet with scope, exact arguments, existing authority, deadline, validation, and output contract. The child's task includes the leaf contract and workflow body, without a generated launch wrapper. The child works directly, launches no agents, and returns to the parent. The parent handles requests for further specialist work and continues the original task.

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
