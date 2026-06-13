## Code Review

Review code for maintainability defects that can be fixed by removing, simplifying, or clarifying code.

Runs a full-project review. No arguments.

### Process

1. Dispatch one sub-agent per subdirectory, recursing into every nested subdirectory, not just top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same review over its own directory; the parent aggregates the findings
2. Flag all dead code regardless of impact rating:
   unreachable blocks, unused exports/functions, commented-out code,
   obsolete feature flags, untested-and-uncalled code paths
3. Report dead code only when there is clear evidence it is unreachable,
   unused, obsolete, or superseded
4. Analyse remaining code for simplification, duplication, and readability issues,
   in that order
5. Ignore formatting preferences, naming taste, and stylistic nits unless they
   materially harm comprehension
6. Rate each remaining finding by impact (1-10):
   4-5 local friction, 6-7 recurring maintenance cost, 8-10 structural drag
7. Output per-improvement format from agent definition
8. Skip findings rated below 4
9. Write the aggregated report to `CODE-REVIEW.md` in the project root
