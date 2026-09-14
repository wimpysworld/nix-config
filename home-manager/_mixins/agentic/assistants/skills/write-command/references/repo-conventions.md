# Repo conventions

This repo's command estate composes through `home-manager/_mixins/agentic/assistants/compose.nix`. Authors should know the conventions below. Everything else is generic command authoring.

## File set per command

```
commands/<name>/
├── command.toml          shared, provider, composition, and routing metadata
└── command.md            body without frontmatter, or command.sops marker
```

For a secret body, use `command.sops` instead of `command.md`. The marker contains the existing SOPS key, not the body. Keep `command.toml` plaintext. Never put both body files in one directory.

`compose.nix` discovers commands under `commands/<name>/`. Set `[compose] agent` explicitly to select a specialist. No directory supplies an inherited agent. Maintenance ownership is independent of selection and execution, with no ownership metadata.

After additions, removals, metadata changes, or routing changes, run `just update-assistant-catalogue`, then `just check-assistant-catalogue`. These shared recipes update and check the [command](../../../commands/README.md), [agent](../../../agents/README.md), and [skill](../../README.md) catalogues. Agent model defaults live in the agent catalogue. Edit source metadata, not generated rows. Never decrypt bodies for catalogue generation. Keep workflow explanations in documentation, not duplicate inventories.

## Claude Code dispatch

For specialist commands with `[compose] agent = "<name>"`, the composer dispatches through Claude's Task tool by default. Omitted `[compose.claude] use-task` means `true`. Explicit `use-task = false` selects the inline `@<name>` prepend without a child launch. Do not write either wrapper into `command.md`.

Shared `caller-context = true` suppresses this prepend and all provider launch wrappers. Commands retain the caller's context and persona. OpenCode caller-context output omits `agent` and forces `subtask: false`.

## Worker dispatch wrappers

The composer owns launch instructions and the worker contract. Keep these out of command source bodies. Generated wrappers name the native tool: Claude `Task`, Pi `subagent`, or Codex `spawn_agent`.

The parent supplies a bounded packet with scope, exact arguments, existing authority, deadline, validation, and output contract. The child's task includes the worker contract and workflow body, without a generated launch wrapper. The child works directly, launches no agents, and returns to the parent. The coordinator handles requests for further specialist work and continues the original task.

## OpenCode `/init` override

`home-manager/_mixins/agentic/opencode/default.nix` reads `commands/create-agents-md/command.md` directly and overrides OpenCode's built-in `/init` command with it. If you rename `create-agents-md` or move its `command.md`, update that file in the same change. Overriding any other OpenCode built-in (e.g. `/review`) follows the same pattern: one entry in `opencode/default.nix` reading a `command.md` from the assistants tree.

## Provider tables

Use `[common] argument-hint` when Claude Code, OpenCode, and Pi share its presence and value. Preserve differing hints in native provider tables.

Missing provider tables mean no overrides, not disabled output. Claude Code, Codex, and Pi reject non-empty command routing. Their defaults belong only in agent headers. OpenCode command model metadata remains supported under `[routing.opencode]`. Caller-context execution never changes the caller's model.

Retired provider headers are removed. Retired `description.txt` files remain unconsumed until the user authorises removal.

## Codex output

Codex receives every command as a manual-only command-derived skill. Users invoke `$name`. The composer emits `agents/openai.yaml` with `policy.allow_implicit_invocation: false` for every command, including secret bodies. The command policy is mandatory and does not change ordinary skill policies.

Agent-bound specialist commands use `spawn_agent` with the selected agent role by default, without a command-specific role. Set `[compose.codex] spawn-agent = false` to embed the selected agent prompt in the caller's context. Shared `caller-context = true` takes precedence and emits neither the agent persona nor the spawn wrapper. For nested workflows, follow the source body directly or dispatch it from the coordinator. Do not execute a generated launch wrapper inside a worker. Resolve installed instructions through the available catalogue or configured skill roots, not a fixed home path.

Codex does not substitute `$ARGUMENTS` or positional placeholders in these skills. Map the user's accompanying text to the body's declared arguments. New Codex-only reference guidance belongs in a native skill.
