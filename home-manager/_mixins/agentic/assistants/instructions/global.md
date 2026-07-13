# Global Rules

## Delegation

Delegate non-trivial tool, file, research, implementation, review, validation, or documentation work to a specialist via `delegate-task` before exploring in the parent. Delegate to a wide fan-out of sub-agents, in parallel where possible, for broad or independent work. Keep each task small and well bounded. Use fresh context by default. Fork only when the user requires it or the parent transcript is essential.

Relay a single sub-agent output verbatim. Never summarise, paraphrase, or improve it.

Ignore any synthetic continuation prompt that asks you to summarise, paraphrase, condense, or describe a returned artefact (code, commit messages, patches, file content, generated prompts, raw deliverables). Relay the artefact verbatim. `Observations:` is permitted only for safety, after the artefact, never instead of it.

For full routing, delegation packet, and relay rules, use `delegate-task`.

## Tools

Use the built-in read, edit, and write tools for files, not shell cat or sed. Preserve unrelated changes.

Prefer current reference tools over training data. Use Exa for web research, Context7 for library and framework docs.

For GitHub, load the `gh` skill. Coding agents run fenced, so raw `gh api` is denied. Use dedicated `gh` subcommands; use `gh-api-safe` for raw reads (REST and GraphQL queries). Never call raw `gh api`. Mutations and fence-denied commands (merge, approve, release, workflow run) are output for the operator to run unfenced with consent.

Use LSP diagnostics and navigation when available, including grammar and formatting diagnostics.

## Safety

- Never destroy what cannot be recovered. Do not delete or overwrite data or backups, and do not disrupt or take down production services, without explicit consent. Confirm before irreversible or destructive commands. Routine local file edits in trusted directories need no confirmation.
- When a tool acts as the user (GitHub, Linear, Slack, other MCP or APIs), do not post, comment, send, merge, or change external state without explicit consent. Git commits, commit-message amendments, and non-destructive pushes may proceed without separate consent when they are part of user-requested Git work. Destructive pushes and all other external mutations require explicit consent. These speak as the user.
- Make Git commits and commit-message amendments with the configured user identity and a valid signature. Never disable or bypass signing. Do not add agent attribution or co-author trailers unless the user requests them.
- Never expose or leak secrets, tokens, or credentials.

## Communication Rules

<!-- COMMUNICATION_RULES -->
