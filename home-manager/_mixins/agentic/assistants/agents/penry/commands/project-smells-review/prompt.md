## Project Smells Review

Hunt for code smells. Not faint aromas - real stench that would make a seasoned developer
in this language ecosystem physically recoil. If it wouldn't make them puke, it doesn't belong here.

Runs a full-project smell hunt. No arguments.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/code-smells.md
```

- `<project>` is the repository directory name, kebab-case.
- Create the directory if it does not exist.

The report is disposable. It lasts for one review only. Never commit it and never write it inside the repo.

Report the written path in your output so the user can find it.

### Classical Smells (non-exhaustive)

| Smell | Signature |
|-------|-----------|
| God Class | One class that knows too much, does too much |
| Feature Envy | Method more interested in another class's data than its own |
| Shotgun Surgery | One change requires touching a dozen files |
| Primitive Obsession | Domain concepts buried in raw strings, ints, booleans |
| Data Clumps | Same group of fields travelling together everywhere |
| Divergent Change | One class changed for many unrelated reasons |
| Dead Code | Commented out, unreachable, never called |
| Long Parameter List | Functions that take five arguments deserve suspicion; eight deserve contempt |
| Inappropriate Intimacy | Classes that know each other's private business |
| Speculative Generality | Abstractions built for futures that never arrived |

### Process

1. Invoke `less-is-more` to reload the Communication Rules before writing anything. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`. If the platform cannot expand a command, apply the Communication Rules directly
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same smell hunt over its own directory; the parent aggregates the findings
3. Identify genuine smells only - not style nits, not minor awkwardness
4. Ignore formatting preferences, naming taste, and idiomatic disagreements unless they indicate a recognised smell
5. Name the smell precisely using classical terminology where applicable
6. If a finding cannot be named as a recognised smell or defended as equivalent structural decay, skip it
7. Prioritise smells that increase change surface, hide intent, or concentrate responsibility
8. Describe why it stinks - direct, no softening
9. Output per-improvement format from agent definition
10. Write the aggregated report to the derived path, then report that path

### Restraint

- A clean report is a valid result. If nothing reaches real stench, say so and stop. Do not manufacture smells to fill the report.
- Report only smells you can point to in the code now. Skip anything that depends on a future the code has not reached.
