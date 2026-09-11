# Frontmatter portability

Use the smallest set that works. Add fields only when a target needs them.

## Always portable

| Field         | Spec  | Notes                                          |
| ------------- | ----- | ---------------------------------------------- |
| `name`        | ≤64   | Must match parent directory. Lowercase+hyphens |
| `description` | ≤1024 | Third person, trigger-rich                     |

## Open spec, optional

| Field           | Notes                                      |
| --------------- | ------------------------------------------ |
| `license`       | SPDX identifier                            |
| `compatibility` | ≤500 chars, free text                      |
| `metadata`      | Arbitrary key/value                        |
| `allowed-tools` | Experimental; controlled environments only |

## Claude Code extensions (ignored elsewhere)

`when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `model`, `effort`, `context`, `agent`, `hooks`, `paths`, `shell`.

Adding these to a portable skill is harmless on Codex/OpenCode/Pi (ignored), but they confuse human readers. Restrict to skills that target Claude Code only.

## Repository routing limits

The composer rejects `[routing.opencode]` and `[routing.codex]` on ordinary skills. These runtimes lack native per-skill model selection in this composition path. Use an agent-backed command for a workflow that needs model or effort pins.

## Codex companion

Codex supports `<skill>/agents/openai.yaml` for UI metadata and `policy.allow_implicit_invocation`. In this repository, author companion fields under `[codex]` in `header.toml`, with policy under `[codex.policy]`. Ordinary reusable skills keep their existing policy or Codex's default implicit invocation. This repository's composer sets `policy.allow_implicit_invocation: false` for every command-derived skill, including secret commands. Keep that mandatory command policy separate from ordinary skills and portable `SKILL.md` frontmatter.

The policy controls implicit selection, not explicit file reads within an authorised workflow. A `$child` reference inside a loaded skill does not recursively load the child. Read dependent instructions through the available catalogue or configured skill roots before applying them.

## Pi specifics

- Discovery: `~/.pi/agent/skills/`, `~/.agents/skills/`, `.pi/skills/`, `.agents/skills/`.
- Invocation: `/skill:<name>`.
- Lenient validation: missing description blocks loading; other issues warn.
- Direct `.md` files (without `SKILL.md`) allowed in Pi-only locations.

## Description listing caps

- Claude Code: `description` + `when_to_use` truncated at 1,536 chars in listing.
- Codex: skill listing capped at ~2% of context window; front-load the use case.
