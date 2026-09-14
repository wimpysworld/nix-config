# Command templates

Three filled examples cover the supported forms. Use `commands/<name>/command.toml` and exactly one `command.md` or `command.sops`. Agent selection uses explicit `[compose] agent`, never directory inheritance. See `SKILL.md` for form selection and catalogue generation.

## Contents

- [Generated Codex policy](#generated-codex-policy)
- [Form A: shim that loads a skill](#form-a-shim-that-loads-a-skill)
- [Form B: trivial standalone](#form-b-trivial-standalone)
- [Form C: standalone with output format](#form-c-standalone-with-output-format)

## Generated Codex policy

The composer adds the mandatory Codex policy to every form below, including commands with secret bodies. Do not copy it into shared provider headers. The generated `agents/openai.yaml` contains:

```yaml
policy:
  allow_implicit_invocation: false
```

Users invoke the generated command as `$name`. Codex receives accompanying arguments as user text, without template substitution. Follow the argument mapping in `SKILL.md`.

## Form A: shim that loads a skill

Save this example under `commands/create-skill/`. The body captures `$ARGUMENTS` and loads the skill without duplicate doctrine.

`command.md`:

```markdown
## Create Skill

Load the `write-skill` skill and run its **create** flow.

Skill name argument: $ARGUMENTS. Use it if provided; otherwise ask for the name and intended trigger context.

Apply `write-skill` end-to-end: frontmatter, body, layout, references, anti-patterns, output format. Do not duplicate that guidance here.
```

`command.toml`:

```toml
[common]
description = "Create Skill 🧩"
argument-hint = "[skill-name]"

[compose]
agent = "rosey"
```

## Form B: trivial standalone

Save this example under `commands/ack/`. The body has no output format.

`command.md`:

```markdown
$ARGUMENTS Assess and acknowledge my message, then yield your turn.
```

`command.toml`:

```toml
[common]
description = "Acknowledge a phase or message ✅"
argument-hint = "[phase]"

[compose]
caller-context = true
```

## Form C: standalone with output format

Save this example under `commands/handover-fresh/`. A standalone body has 30-60 lines with an output template and constraints. Persona stays in the selected agent.

`command.md`:

```markdown
## Project Handover (Fresh Session)

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

`command.toml`:

```toml
[common]
description = "Handover 📤"
argument-hint = "[focus]"

[compose]
agent = "rosey"
caller-context = true
```

Omit `argument-hint` when the command takes no argument. Keep Claude Code, Codex, and Pi commands model-neutral. Put their routing defaults in the selected agent's `header.toml`. OpenCode command model metadata support remains unchanged.
