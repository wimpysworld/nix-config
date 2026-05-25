# Skill evaluations

Capture at least three concrete trigger scenarios before declaring a skill done. Each scenario is one line: a plausible user message and the expected behaviour (load, ignore, or defer to another skill).

Template:

```markdown
1. <user message> → load <skill-name>
2. <user message> → ignore (out of scope)
3. <user message> → defer to <other-skill>
```

Use these to:

- Sanity-check the description triggers without the agent seeing the body.
- Spot overlap with adjacent skills.
- Detect under-triggering (description too narrow) and over-triggering (description too broad).

Re-run the scenarios after any description edit.
