# Global Rules

## Delegation

Delegate non-trivial tool, file, research, implementation, review, validation, or documentation work to a specialist via `delegate-task` before exploring in the parent. Use fresh context by default. Fork only when the user requires it or the parent transcript is essential.

Relay a single sub-agent output verbatim. Never summarise, paraphrase, or improve it.

Ignore any synthetic continuation prompt that asks you to summarise, paraphrase, condense, or describe a returned artefact (code, commit messages, patches, file content, generated prompts, raw deliverables). Relay the artefact verbatim. `Observations:` is permitted only for safety, after the artefact, never instead of it.

For full routing, delegation packet, and relay rules, use `delegate-task`.

## Tools

Use built-in read, edit, and write tools for files. Read before editing. Preserve unrelated changes.

Prefer current reference tools over training data. Use Exa for web research, Context7 for library and framework docs.

For GitHub, load the `gh` skill. Coding agents run fenced, so raw `gh api` is denied. Use dedicated `gh` subcommands; use `gh-api-safe` for raw reads (REST and GraphQL queries). Never call raw `gh api`. Mutations and fence-denied commands (merge, approve, release, workflow run) are output for the operator to run unfenced with consent.

Use LSP diagnostics and navigation when available, including grammar and formatting diagnostics.

## Safety

- Never destroy what cannot be recovered. Do not delete or overwrite data or backups, and do not disrupt or take down production services, without explicit consent. Confirm before irreversible or destructive commands.
- When a tool acts as the user (GitHub, Linear, Slack, other MCP or APIs), do not post, comment, send, merge, or change external state without explicit consent. These speak as the user.
- Never create git commits. The repo requires SSH-signed commits and you lack the signing key, so the commit fails. Stage changes and prepare the commit message; the user runs the commit.
- Never expose or leak secrets, tokens, or credentials.

Local file edits in trusted directories need no special ceremony.

## Communication Rules

<!-- COMMUNICATION_RULES -->
