---
agent: "donatello"
description: "Orientate 🧭"
---

## Project Orientation

Orient yourself efficiently with the codebase before we begin.

### 1. Check for AGENTS.md

**If AGENTS.md exists at repository root:**
- Read AGENTS.md only (comprehensive project guide)
- Skip to step 4 (Report)

**If AGENTS.md missing:**
- Read README.md for project overview
- Check for CONTRIBUTING.md or ARCHITECTURE.md (if they exist)
- Skim recent git commits (last 5-10 with `git log --oneline -10`)

### 2. Identify Project Type

Quickly determine:
- Primary language/framework (check file extensions, package manifests)
- Build system (presence of Makefile, package.json, flake.nix, etc.)
- Test framework (if any)

Do NOT read entire codebases or documentation files verbatim.

### 3. Recall Context

From previous sessions (if applicable):
- Recent decisions or work in progress
- Known constraints or issues
- Project-specific patterns

### 4. Report

Provide concise orientation (target 50-100 lines total):

**Summary** (2-3 sentences):
- What we're building
- Current state (version, stability)

**Tech Stack** (bullet points):
- Language, framework, build tools
- Key dependencies

**Development Commands** (3-5 most common):
- Build, test, run commands

**Key Conventions** (bullet points):
- Code style (if specified)
- File structure pattern
- Testing requirements

**Constraints** (if any):
- Version locks
- Platform requirements
- Security considerations

**Ready**: Confirm orientation complete

**Efficiency Guidelines:**
- Prioritise AGENTS.md if it exists (skip everything else)
- Use glob/grep to find files, not extensive directory listings
- Read configuration files (package.json, flake.nix) over source code
- Focus on actionable information (commands, conventions, constraints)
- Omit generic project descriptions or boilerplate
- If uncertain, note gaps and ask rather than over-researching
