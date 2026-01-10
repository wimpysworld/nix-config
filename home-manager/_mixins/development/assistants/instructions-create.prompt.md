---
agent: "rosey"
description: "Create AI assistant instructions 🤖"
---

## Generate AI Assistant Instructions

Create an AGENTS.md file for the current project using the official format from https://agents.md/ - a standard Markdown file that works across 60k+ projects and all major AI coding agents.

**Process:**

1. **Analyze the project:**
   - Tech stack (languages, frameworks, build tools)
   - Existing conventions (code style, naming, file structure)
   - Build, test, and development commands
   - Documentation (README, contributing guides)
   - Dependencies and package manifests

2. **Draft instructions** - pure Markdown, use relevant headings:
   
   **Popular sections** (adapt to project):
   - Project overview (optional brief context)
   - Setup/installation commands
   - Build and test commands
   - Code style guidelines
   - Development workflow tips
   - Testing instructions
   - PR/commit message guidelines
   - Security considerations
   - Architecture notes

3. **Keep practical:**
   - Target 50-150 lines for typical projects
   - Focus on commands, conventions, and gotchas
   - Use bullet points for clarity
   - Include actual commands agents can run
   - Skip sections that don't apply

**Example format:**

```markdown
# AGENTS.md

## Setup commands

- Install dependencies: `npm install`
- Start development server: `npm run dev`
- Run tests: `npm test`

## Build and test commands

- Build: `npm run build`
- Run tests: `npm test`
- Run linter: `npm run lint`
- Run type checker: `npm run type-check`

## Code style

- TypeScript strict mode enabled
- Use single quotes, no semicolons
- Prefer functional patterns over classes
- Use `const` over `let` when possible

## Testing instructions

- All features require unit tests
- Run `npm test` before committing
- Integration tests live in `/tests/integration`
- Use `npm test -- --watch` during development

## PR/commit guidelines

- Follow [Conventional Commits](https://www.conventionalcommits.org/) specification
- Run linter and tests before opening PR
- All tests must pass before merging
- Keep PRs focused on a single concern

## Security considerations

- Never commit secrets or API keys
- Use environment variables for sensitive data
- Add `.env` and `.env.*` to `.gitignore`
```

**Key principles:**

- Commands should be copy-pasteable
- Instructions should be project-specific, not generic
- Focus on common gotchas and non-obvious conventions
- Skip sections that don't apply to the project

**Output Format:**

Provide:
1. Complete AGENTS.md file content (pure Markdown)
2. Location: `AGENTS.md` at repository root (or subdirectory for monorepos)
3. Brief rationale (3-5 bullets) for key inclusions

**Constraints:**

- Pure Markdown only - no frontmatter, no YAML
- No generic advice ("write good code", "test thoroughly")
- Focus on project-specific commands and conventions
- Include runnable commands agents can execute
- Use British English spelling if project conventions unclear