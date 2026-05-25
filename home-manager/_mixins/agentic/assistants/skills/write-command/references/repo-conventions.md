# Repo conventions

This repo's command estate composes through `home-manager/_mixins/agentic/assistants/compose.nix`. Authors should know the four conventions below; everything else is generic command authoring.

## File set per command

```
commands/<name>/                              (standalone)
agents/<agent>/commands/<name>/               (agent-scoped)
├── prompt.md             body, required
├── description.txt       one-line label, required
├── header.claude.yaml    required (may be empty)
├── header.opencode.yaml  required (may be empty)
└── header.pi.yaml        optional (omit when no positional arg)
```

`compose.nix` discovers commands by directory listing - no codegen edits when adding a new command.

## Agent prepend on Claude Code

When `header.opencode.yaml` carries `agent: <name>` and the command lives under `agents/<name>/commands/`, `compose.nix` prepends `@<name>` on its own line before the body for the Claude Code output. Do not write `@agent` into `prompt.md`; the composer adds it.

## `use-task: true` (repo-local)

`header.claude.yaml: use-task: true` rewrites the Claude Code body into:

```
Use the Task tool to launch the <agent> agent for the following task:

<prompt.md body>
```

This dispatches the command through Claude's Task tool instead of the `@agent` prepend. Use sparingly; the prepend pattern is the default.

## OpenCode `/init` override

`home-manager/_mixins/agentic/opencode/default.nix` (around lines 110-120) reads `agents/rosey/commands/create-agents-md/prompt.md` directly and overrides OpenCode's built-in `/init` command with it. If you rename `create-agents-md` or move its `prompt.md`, update that file in the same change. Overriding any other OpenCode built-in (e.g. `/review`) follows the same shape: one entry in `opencode/default.nix` reading a `prompt.md` from the assistants tree.

## Pi header optionality

`header.pi.yaml` is the only optional header. Supply it whenever the command accepts an argument so Pi can display the same `argument-hint` as Claude Code and OpenCode (matches `handover-fork`, `handover-fresh`, `orientate`, `botsnack`, and every Rosey `create-*` / `update-*` shim). Omit it only when the command takes no positional argument and would otherwise be empty. `compose.nix` uses `readOptionalFile` for it; an empty file is acceptable but adds noise.

## Codex output

The repo's current `compose.nix` does not emit per-command output for Codex. Codex coverage runs through skills; new Codex work belongs in `write-skill`.
