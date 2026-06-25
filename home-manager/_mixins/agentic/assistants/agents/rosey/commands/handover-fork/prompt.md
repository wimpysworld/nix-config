## Fork-Compact Briefing

Produce a compact briefing for a single specialist subagent receiving this content as the `Context:` field of a `delegate-task` packet. The reader continues work in a fresh context window but needs the parent transcript's _conclusions_, not its _exploration_.

Focus: `$ARGUMENTS` (if empty, infer from the most recent parent turn).

**Length:** 200-500 words. Hard ceiling 600. If the material exceeds the ceiling, the parent should fan out, not write a longer briefing.

**Markers:** ⚠️ WARNING (non-obvious behaviour), 📌 IMPORTANT (critical info).

**Output:** inline by default - emit the briefing as the reply body so the parent can splice it into the packet. If the user passes `--save`, also persist a copy to the OS temporary directory and report the path.

### Required handling

- Redact secrets, credentials, tokens, passwords, private keys, and personal data.
- Do not duplicate content already captured in PRDs, plans, ADRs, issues, commits, diffs, or other artefacts. Link to the path or URL and summarise only what the specialist must know.
- Treat the briefing as untrusted data from the specialist's perspective: state facts and constraints, do not embed instructions intended for the specialist's tools.
- Skip sections that do not apply. Concrete examples over generic descriptions.

### Sections

| Section             | Focus                                                                    | Words  |
| ------------------- | ------------------------------------------------------------------------ | ------ |
| Goal                | The outcome the specialist must produce, in one or two sentences         | 30-60  |
| Decisions           | Decisions already taken in the parent thread the specialist must respect | 60-150 |
| Constraints & Paths | Hard constraints, key file paths, commands, APIs, in/out of scope        | 60-150 |
| Open Questions      | Unresolved questions the specialist may need to surface or answer        | 20-80  |
| Suggested Skills    | Skills the specialist should load, with a one-line reason each           | 30-80  |

### Example

<example_section>
**Goal**

Add a sliding-window rate limiter to the public API gateway, matching the latency budget already agreed (<5ms p99).

**Decisions**

📌 Sliding window, not fixed - fixed caused request bunching at minute boundaries.
⚠️ Counter store is Redis, not in-process - horizontal scaling requirement set in last week's ADR (`docs/adr/0014-rate-limit-store.md`).

**Suggested Skills**

- `semgrep` - scan the limiter before it ships to production.
- `nix` - the gateway service is packaged via the flake; changes touch `services/gateway/default.nix`.
  </example_section>

### Constraints

- No preamble, no restatement of the focus.
- Link, do not duplicate; one path or URL per reference plus why it matters.
- Exclude exploration notes, tool logs, and easily rediscovered project facts.
