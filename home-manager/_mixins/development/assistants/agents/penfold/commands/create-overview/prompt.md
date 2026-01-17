## Research Overview Document

Create overview enabling downstream agents to continue without reverse-engineering your research.

### Length

| Scope | Words | Examples |
|-------|-------|----------|
| Feature | 400-700 | API endpoint, CLI flag, UI component |
| Small system | 700-1200 | Utility tool, microservice |
| Major project | 1200-2000 | Platform, multi-service architecture |

### Markers

📌 KEY (critical insight), ⚠️ CAVEAT (limitation/uncertainty), → (recommendation)

### Sections

| Section | Focus |
|---------|-------|
| Summary | What, why, key conclusion - one paragraph |
| Context | Background, assumptions, constraints |
| Findings | Core research by theme - synthesised, not a search log |
| Options | 2-4 approaches with trade-offs; table format |
| Open Questions | Unresolved items needing decision or investigation |
| Next Steps | Concrete actions for downstream agents |

### Example

<example_section>
## Options

| Option | Pros | Cons | Effort |
|--------|------|------|--------|
| 📌 **Nix flake overlay** | Native, declarative, pinned | Steeper learning curve | M |
| **Standalone script** | Simple, no Nix knowledge | Manual updates, not reproducible | S |

→ Recommend overlay if this becomes a recurring pattern.

⚠️ CAVEAT: Assumes nixpkgs-unstable; stable may lack dependencies.
</example_section>

<example_section>
## Findings

**State management**: Svelte 5 runes eliminate need for external stores in most cases. 
`$state` handles reactivity; `$derived` replaces computed stores. 📌 KEY: Runes are 
compile-time - no runtime overhead.

**Persistence**: Three viable patterns emerged: localStorage (simple, sync), IndexedDB 
(complex, async), or server-sync (requires auth). ⚠️ CAVEAT: localStorage has 5MB limit.
</example_section>

### Constraints

- Skip sections that don't apply
- Findings over process - what you learned, not how you searched
- No hedging language ("perhaps", "might", "could potentially")
- No repetition across sections
