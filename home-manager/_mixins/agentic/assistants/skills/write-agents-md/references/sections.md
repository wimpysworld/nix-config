# Canonical section template

Pick the headings that carry project-specific content. Skip the rest. Order is conventional, not required.

```markdown
# <Project name>

<One-sentence purpose.>

## Setup

- <Command to bootstrap a working dev env, e.g. `direnv allow` or `npm install`.>

## Build and test

- Build: `<command>`
- Run tests: `<command>`
- Lint: `<command>`
- Format: `<command>`

## Code style

- <Project-specific rule the model will not infer from reading the code.>

## Testing

- <How to scope tests, what to run before commit, coverage expectations.>

## PR and commit conventions

- Branch naming: `<pattern>`
- Commit format: Conventional Commits 1.0.0 (or named alternative).
- Required checks: `<list>`

## Architecture notes

- <Non-obvious module boundary, data flow, or layout.>

## Security and secrets

- <What not to commit. Where secrets live. Pre-commit hooks if any.>

## Gotchas

- <Recurring surprise an agent should know about up front.>
```

Per-section guidance:

- **Project overview.** One sentence. Skip the marketing.
- **Setup.** Commands needed once, in order. Not a tutorial.
- **Build and test.** Copy-pasteable. Each command runnable as-is from the repo root.
- **Code style.** Project-specific only. Do not restate language defaults. Link to a longer style guide rather than inline it.
- **Testing.** Distinguish "before commit" checks from "in CI" checks.
- **PR and commit conventions.** Title format, branch naming, required reviewers.
- **Architecture notes.** Only the non-obvious. A directory tree is rarely useful.
- **Security and secrets.** Where secrets live, what must not be committed, scanning hooks.
- **Gotchas.** The "I wish I had known" list.

Drop any heading whose body would be empty or generic.
