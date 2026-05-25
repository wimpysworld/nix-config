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

## Codex companion

Codex supports `agents/openai.yaml` next to the skill for UI metadata and `allow_implicit_invocation`. Only needed when publishing skills to Codex users.

## Pi specifics

- Discovery: `~/.pi/agent/skills/`, `~/.agents/skills/`, `.pi/skills/`, `.agents/skills/`.
- Invocation: `/skill:<name>`.
- Lenient validation: missing description blocks loading; other issues warn.
- Direct `.md` files (without `SKILL.md`) allowed in Pi-only locations.

## Description listing caps

- Claude Code: `description` + `when_to_use` truncated at 1,536 chars in listing.
- Codex: skill listing capped at ~2% of context window; front-load the use case.
