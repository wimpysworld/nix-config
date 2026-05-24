# Command templates

Three filled examples covering the supported shapes. Copy and edit; do not invent a fourth shape unless §3.1 of `SKILL.md`'s decision rules clearly demand it.

## Shape A: shim that loads a skill

Five-line body. Captures `$ARGUMENTS`, names the flow, loads the skill, refuses to duplicate doctrine. Mirrors `create-skill`, `create-assistant`, `create-agents-md`.

`prompt.md`:

```markdown
## Create Skill

Load the `write-skill` skill and run its **create** flow.

Skill name argument: $ARGUMENTS. Use it if provided; otherwise ask for the name and intended trigger context.

Apply `write-skill` end-to-end: frontmatter, body, layout, references, anti-patterns, output shape. Do not duplicate that guidance here.
```

`description.txt`:

```text
Create Skill 🧩
```

`header.claude.yaml`:

```yaml
argument-hint: "[skill-name]"
model: opus
```

`header.opencode.yaml`:

```yaml
agent: rosey
```

`header.pi.yaml`:

```yaml
argument-hint: "[skill-name]"
```

## Shape B: trivial standalone

One- or two-line body. No format. Mirrors `ack`, `ready`.

`prompt.md`:

```markdown
$ARGUMENTS Assess and acknowledge my message, then yield your turn.
```

`description.txt`:

```text
Acknowledge a phase or message ✅
```

`header.claude.yaml`:

```yaml
argument-hint: "[phase]"
```

`header.opencode.yaml`:

```yaml

```

`header.pi.yaml`:

```yaml
argument-hint: "[phase]"
```

## Shape C: standalone with output format

30-60 line body owning a non-trivial output template, sections table, and constraints. Mirrors `handover`, `orientate`. No persona; persona lives in the bound agent.

`prompt.md`:

```markdown
## Project Handover Document

Create a handover enabling a fresh engineer or agent to continue without reverse-engineering decisions.

If the user supplied a focus, tailor the handover to that next-session goal.

**Length:** 800-1200 words (typical), 1500-2000 (major systems)

### Required handling

- Save outside the workspace in the OS temporary directory.
- Redact secrets, credentials, tokens, private keys, personal data.
- Link to existing PRDs / ADRs / issues instead of duplicating.

### Sections

| Section       | Focus                                                 | Words   |
| ------------- | ----------------------------------------------------- | ------- |
| Context       | What, why, current state, architecture (one sentence) | 100-150 |
| Key Decisions | Problem → approach → rejected alternatives            | 150-250 |
| …             | …                                                     | …       |

### Constraints

- Skip sections that don't apply.
- Concrete examples over generic descriptions.
- Exclude easily discoverable information.
```

`description.txt`:

```text
Handover 📤
```

`header.claude.yaml`:

```yaml
model: sonnet
```

`header.opencode.yaml`:

```yaml
agent: rosey
```

(No `header.pi.yaml`: the command takes no positional arg.)
