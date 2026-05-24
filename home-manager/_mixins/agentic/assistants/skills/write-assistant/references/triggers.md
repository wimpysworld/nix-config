# Sub-agent description and triggers

The `description` field is the routing surface. The router selects an agent by matching the user's intent against descriptions in third person, exactly like skills. See `write-skill/references/portability.md` for the frontmatter field matrix; the rules here are agent-specific.

## Description structure

One sentence stating what the agent does and when to trigger it. Front-load the use case so it survives listing truncation.

```yaml
description: Reviews TypeScript PRs for type safety, exhaustiveness, and union variant coverage.
```

Add synonyms and trigger phrases the user might use:

```yaml
description: |
  Reviews TypeScript PRs for type safety, exhaustiveness, and union variant
  coverage. Use when the user mentions "review", "type check", "narrowing",
  or asks about `as const` or discriminated unions.
```

## Claude Code `<example>` blocks

Claude Code sub-agents support 2-4 `<example>` blocks inside the description to bias routing on concrete scenarios.

```markdown
description: |
Reviews TypeScript PRs for type safety and exhaustive switch coverage.

  <example>
  Context: a PR adds a new union variant.
  user: "Review #1234."
  assistant: "I'll use the example-reviewer agent to check exhaustive switches."
  <commentary>
  Triggered because the PR touches a discriminated union and review is requested.
  </commentary>
  </example>

  <example>
  Context: a refactor removes a union variant.
  user: "Can you check `parseEvent` after my refactor?"
  assistant: "I'll use the example-reviewer agent."
  <commentary>Removed variants commonly leave non-exhaustive switches.</commentary>
  </example>
```

Rules:

- 2-4 examples. More dilutes routing.
- Each example: one Context line, one user line, one assistant line, one `<commentary>` line.
- Show the **trigger reason** in commentary, not the agent's full plan.

## Portability

`<example>` blocks degrade gracefully on Codex, OpenCode, and Pi (treated as extra description text) but add tokens. For portable agents that target multiple platforms, keep the description plain prose and rely on trigger phrases.

## Listing caps

- Claude Code: description + `when_to_use` truncated at 1,536 chars in listing.
- Codex: agent listing capped at ~2% of context window.

Front-load the use case so it survives.

## Anti-patterns

- Self-referential descriptions ("This agent reviews PRs"). Drop "This agent".
- First-person descriptions ("I review PRs").
- Triggers hidden in the body instead of the description.
- More than 4 `<example>` blocks.
- `<example>` blocks for portable agents that target Codex or Pi.
