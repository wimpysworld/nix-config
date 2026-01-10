---
agent: "rosey"
description: "Consolidate AI assistant instructions 🔄"
---

## Consolidate to AGENTS.md

Audit all AI assistant instruction files in the project and consolidate them into a single AGENTS.md file using the official format from https://agents.md/

**Process:**

1. **Find all instruction files:**
   - AGENTS.md (existing)
   - CLAUDE.md, CLAUDE.local.md, .claude/CLAUDE.md
   - .github/copilot-instructions.md
   - .cursorrules, .cursor/rules
   - .github/instructions/*.instructions.md (GitHub Copilot path-specific)
   - Any other tool-specific instruction files

2. **Analyze and merge:**
   - Read all found instruction files
   - Identify unique, project-specific instructions
   - Remove duplicates and generic advice
   - Detect conflicts between instructions (flag these)
   - Extract runnable commands, conventions, gotchas

3. **Create/update AGENTS.md:**
   - Use official format (pure Markdown, no frontmatter)
   - Merge instructions by logical sections:
     - Setup commands
     - Build and test commands
     - Code style guidelines
     - Development workflow tips
     - Testing instructions
     - PR/commit guidelines
     - Security considerations
   - Target 50-150 lines
   - Include actual runnable commands
   - Skip empty or irrelevant sections

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

4. **Clean up legacy files:**
   - List instruction files to be removed
   - Keep tool-specific config files (settings, not instructions)
   - Ask for confirmation before deleting
   - Provide clear rationale for each deletion

**Output Format:**

Provide:
1. **Audit summary:**
   - Files found with line counts
   - Conflicts or duplicates detected
   - Tool-specific config files preserved

2. **Proposed AGENTS.md:**
   - Complete file content
   - Highlight merged sections
   - Note any ambiguous instructions

3. **Cleanup plan:**
   - Files to delete with rationale
   - Files to keep with reason
   - Confirmation prompt before proceeding

4. **Migration notes:**
   - Any instructions that need clarification
   - Suggested improvements to consolidated file

**Constraints:**

- Never delete files without explicit confirmation
- Preserve tool-specific configuration (not just instructions)
- Warn about conflicting instructions
- Flag generic advice for potential removal
- Keep only project-specific, actionable instructions
- Use British English spelling if conventions unclear
