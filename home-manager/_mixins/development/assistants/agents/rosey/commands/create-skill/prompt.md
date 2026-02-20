## Create Skill

Create a `SKILL.md` for a reusable agent skill compatible with Claude Code, OpenCode, and GitHub Copilot.

**Gather from user (ask if not provided):**

- **Required:** Skill name (lowercase, hyphens only), purpose, when Copilot/Claude should load it
- **Optional:** Supporting files needed (scripts, examples, reference docs)

**Skill types - clarify which applies:**

- **Reference** - background knowledge loaded automatically when relevant (coding conventions, domain context)
- **Task** - step-by-step workflow invoked manually with `/skill-name` (add `disable-model-invocation: true`)

**Output: `SKILL.md` with:**

```markdown
---
name: <skill-name>
description: <when to use this skill - one sentence, specific enough to trigger correctly>
---

<instructions>
```

**Constraints:**

- `name` must match the directory name: lowercase, hyphens only, 1-64 characters
- `description` drives automatic loading - make it specific, include trigger phrases
- Keep `SKILL.md` under 500 lines; move large reference material to supporting files
- Add `disable-model-invocation: true` for task skills with side effects
- Add `user-invocable: false` for background knowledge not meant as a slash command
- British English
- Output the `SKILL.md` content in a code block ready to save
