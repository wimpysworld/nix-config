# Command capability

Create or update a user-invoked command through the repository's command composition system.

## Author

1. Load `write-command` and read it in full before editing.
2. Follow its decision rules for a shim, standalone command, or standalone command with an output format. Do not reproduce its doctrine here.
3. Inspect nearby commands, the owning agent, composition code, required provider headers, and discovery rules.
4. Put reusable workflow guidance in a skill. Keep a command shim limited to invocation, `$ARGUMENTS` handling, and delegation to that skill.
5. Use `$ARGUMENTS` for a portable free-form argument. Keep argument hints identical across every provider header that supports them.
6. Bind the command to its owning agent through the repository's native header or composer. Do not embed the agent persona in the shared body.

When no composer exists, verify each supported client's current project path and format before writing:

| Client      | Repository form to verify                                          |
| ----------- | ------------------------------------------------------------------ |
| Claude Code | `.claude/commands/<name>.md` or a skill exposed as a command       |
| Codex       | A skill under the current skills path; custom prompts are obsolete |
| OpenCode    | `.opencode/commands/<name>.md`                                     |
| Pi          | `.pi/prompts/<name>.md`                                            |

Do not assume that provider frontmatter fields or agent routing work on another client. If Codex receives commands as generated skills, validate that generated skill as well as the slash-command forms.

## Validate

1. Check that every required source file and provider header exists and parses.
2. Run the repository composer or evaluation for Claude Code, OpenCode, Pi, and any generated Codex skill form.
3. Inspect each emitted artefact. Confirm its description, argument hint, `$ARGUMENTS` text, agent binding or launch wrapper, and body.
4. Confirm the command appears in each installed client's discovery output when such diagnostics exist.
5. Check flat command and skill namespaces for collisions.
6. Run repository formatting, evaluation, and required checks.

Do not claim cross-client support from the shared prompt alone. Validate the composed provider forms.
