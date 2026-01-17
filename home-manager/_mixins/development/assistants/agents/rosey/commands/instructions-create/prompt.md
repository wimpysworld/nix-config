## Generate AGENTS.md

Create AGENTS.md for current project using format from https://agents.md/

**Analyse project:**

- Tech stack, frameworks, build tools
- Existing conventions (style, naming, structure)
- Build, test, dev commands
- Package manifests

**Include sections where applicable:**

- Setup/installation commands
- Build and test commands
- Code style guidelines
- Testing instructions
- PR/commit guidelines
- Security considerations
- Architecture notes (if non-obvious)

**Example section:**

```markdown
## Build and test commands

- Build: `npm run build`
- Run tests: `npm test`
- Run linter: `npm run lint`
```

**Constraints:**

- Skip sections with no project-specific content
- Commands must be runnable (test them if possible)
- Target 50-150 lines
- British English
