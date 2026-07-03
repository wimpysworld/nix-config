## Code Smell Review

Hunt for code smells. Not faint aromas - real stench that would make a seasoned developer
in this language ecosystem physically recoil. If it wouldn't make them puke, it doesn't belong here.

Runs a full-project smell hunt. No arguments.

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

1. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same smell hunt over its own directory; the parent aggregates the findings
2. Identify genuine smells only - not style nits, not minor awkwardness
3. Ignore formatting preferences, naming taste, and idiomatic disagreements unless they indicate a recognised smell
4. Name the smell precisely using classical terminology where applicable
5. If a finding cannot be named as a recognised smell or defended as equivalent structural decay, skip it
6. Prioritise smells that increase change surface, hide intent, or concentrate responsibility
7. Describe why it stinks - direct, no softening
8. Output per-improvement format from agent definition
9. Write the aggregated report to `CODE-SMELLS.md` in the project root

### Restraint

- A clean report is a valid result. If nothing reaches real stench, say so and stop. Do not manufacture smells to fill the report.
- Report only smells you can point to in the code now. Skip anything that depends on a future the code has not reached.
