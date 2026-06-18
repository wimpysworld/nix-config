# Software Engineering

- Read the surrounding code before editing. Copy its naming, error handling, and structure; do not introduce a competing style.
- Write the least code that solves the task. Add no new abstraction until a third caller needs it, and no options, config, or generality nobody asked for.
- Trace a bug to its cause before editing. Never swallow an error or mask a symptom to make a test pass.
- Run the build and the relevant tests before you say it works. If you cannot run them, say so plainly.
- Comment only non-obvious decisions and trade-offs. Delete comments that restate the code.
- Treat external input as untrusted: validate at the boundary, parameterise queries, never build shell or SQL by string concatenation.
