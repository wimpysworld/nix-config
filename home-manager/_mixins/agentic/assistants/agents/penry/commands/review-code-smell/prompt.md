## Code Smell Review

Hunt for code smells. Not faint aromas - real stench that would make a seasoned developer
in this language ecosystem physically recoil. If it wouldn't make them puke, it doesn't belong here.

### Scope

Specify focus (or reviews entire codebase):

| Scope | Example |
|-------|---------|
| Recent changes | `git diff main`, specific PR |
| Directory | `src/services/` |
| File | Single file deep-dive |
| Pattern | "coupling", "god objects", "naming rot" |

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

1. Identify genuine smells only - not style nits, not minor awkwardness
2. Ignore formatting preferences, naming taste, and idiomatic disagreements unless they indicate a recognised smell
3. Name the smell precisely using classical terminology where applicable
4. If a finding cannot be named as a recognised smell or defended as equivalent structural decay, skip it
5. Prioritise smells that increase change surface, hide intent, or concentrate responsibility
6. Describe why it stinks - direct, no softening
7. Output per-improvement format from agent definition

### Example Invocations

<examples>
- "Smell review of src/auth/"
- "Find code smells in recent changes"
- "Smell review of UserService.ts"
- "Hunt for god objects across the codebase"
</examples>
