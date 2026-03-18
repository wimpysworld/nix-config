## Update Skill

Improve an existing `SKILL.md` and its supporting files. Preserve the skill's name and directory structure; improve description triggering, instruction quality, and file organisation.

**Gather from user (ask if not provided):**

- **Required:** Path to the skill directory or `SKILL.md`
- **Optional:** Specific issues to address (poor triggering, outdated instructions, missing examples)

**Process:**

1. Read `SKILL.md` and all supporting files in the skill directory
2. Identify the skill's original intent before proposing changes
3. Diagnose issues across these areas:
   - **Description** - specific enough, trigger phrases present, slightly pushy?
   - **Instructions** - imperative form, explains *why*, free of heavy-handed MUSTs?
   - **Structure** - large reference material inlined when it should be in `references/`?
   - **Bundled resources** - scripts duplicated per invocation when they could live in `scripts/`?

**Writing principles (apply when revising instructions):**

- Use imperative form ("Run X", not "You should run X")
- Explain *why* things matter rather than issuing bare mandates - models follow reasoning better than rules
- Define output formats with exact templates where format matters; use brief examples for judgment or style tasks
- Remove anything not pulling its weight; generalise rather than overfitting to specific inputs

**Description field guidance:**

The description is the primary trigger mechanism. Claude tends to undertrigger skills, so make descriptions slightly pushy: include what the skill does AND specific contexts for when to use it.

<example_good>
Use when the user mentions dashboards, data visualisation, or wants to display metrics, even if they don't ask for a 'dashboard' explicitly.
</example_good>

<example_bad>
How to build a simple dashboard.
</example_bad>

**Output:**

- Updated `SKILL.md` in a code block ready to save
- Updated supporting files if structure changed (with file paths)
- A changelog: what changed and why - if the skill already follows good patterns, say so explicitly

**Constraints:**

- Preserve `name` field exactly - never rename a skill or its directory
- Keep `SKILL.md` under 500 lines; move large reference material to `references/` with a table of contents for files over 300 lines
- British English
- Output updated file content in code blocks ready to save
