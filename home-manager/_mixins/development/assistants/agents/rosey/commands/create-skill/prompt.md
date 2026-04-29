## Create Skill

Create a `SKILL.md` for a reusable agent skill compatible with Claude Code, OpenCode, and Codex.

**Gather from user (ask if not provided):**

- **Required:** Skill name (lowercase, hyphens only), purpose, when the agent should load it
- **Optional:** Supporting files needed (scripts, examples, reference docs)

**Skill types - clarify which applies:**

- **Reference** - background knowledge loaded automatically when relevant (coding conventions, domain context); add `user-invocable: false`
- **Task** - step-by-step workflow invoked manually with `/skill-name`; add `disable-model-invocation: true` for skills with side effects

**Skill structure:**

```
skill-name/
├── SKILL.md          required
├── scripts/          executable helpers bundled with the skill
├── references/       docs loaded into context as needed
└── assets/           templates, icons, static files
```

Skills load in three levels: **metadata** (name + description, always in context), **SKILL.md body** (loaded when triggered), **bundled resources** (loaded on demand). Put large reference material in `references/` and point to it from SKILL.md rather than inlining it.

**Output: `SKILL.md` with:**

~~~markdown
---
name: <skill-name>
description: <when to use this skill>
---

<instructions>
~~~

**Writing the instructions:**

- Use imperative form ("Run X", not "You should run X")
- Explain *why* things matter rather than issuing bare mandates - models follow reasoning better than rules, and heavy-handed MUSTs are a yellow flag
- Define output formats with exact templates where format matters; use brief examples for judgment or style tasks
- Keep the prompt lean - remove anything not pulling its weight; generalise from examples rather than overfitting to specific inputs

**Description field guidance:**

The description is the primary trigger mechanism. Claude tends to undertrigger skills, so make descriptions slightly pushy: include what the skill does AND specific contexts for when to use it, even if the user doesn't name the skill directly.

<example_good>
Use when the user mentions dashboards, data visualisation, or wants to display metrics data, even if they don't ask for a 'dashboard' explicitly.
</example_good>

<example_bad>
How to build a simple dashboard.
</example_bad>

**Constraints:**

- `name` must match the directory name: lowercase, hyphens only, 1-64 characters
- Keep `SKILL.md` under 500 lines; move large reference material to `references/` with a table of contents for files over 300 lines
- British English
- Output the `SKILL.md` content in a code block ready to save
