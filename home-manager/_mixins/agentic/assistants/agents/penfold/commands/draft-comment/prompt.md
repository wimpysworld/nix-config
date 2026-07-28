## Draft Comment

Draft one comment for an existing thread. This step drafts only; it never posts or mutates any surface.

Target argument: $ARGUMENTS. This is the thread URL, optionally followed by the angle or point the user wants to make. If $ARGUMENTS is blank, ask which thread and wait.

The thread URL may be a GitHub issue, pull request, or review comment; a Linear issue or comment; or a Slack message or thread.

### Forbidden Commands

These bans govern this drafting step. They do not restrict the command that invoked it.

NEVER execute while drafting:

- `gh issue comment` / `gh pr comment` / `gh pr review` - this step produces the comment, the caller posts it
- `gh-review-reply` - allowed under Fence, but it posts; this step produces the comment, the caller posts it
- Raw `gh api` - denied outright; use `gh-api-safe` for raw reads
- The Linear `save_comment` tool - this step produces the comment, the caller saves it
- The Slack message-sending tools - this step produces the comment, the caller sends it
- Any command that closes, merges, locks, or otherwise changes thread state

### Process

1. Invoke `less-is-more` to reload the Communication Rules before drafting. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`. If the platform cannot expand a command, apply the rules restated below instead
2. Load the `contribution-voice` skill and follow it. It governs the structure of text published under the user's name
3. Read the thread before writing. Use dedicated `gh` subcommands for GitHub; raw `gh api` is denied, so use `gh-api-safe` for raw reads. Use the Linear MCP tools for Linear and the Slack MCP tools for Slack. Read enough of the thread to answer what was actually asked, including what others already said, so the comment does not repeat a point someone has made
4. Draft one comment and output it in a single fenced markdown block. This block is the deliverable and must reach the caller unchanged

The comment answers the question asked and nothing adjacent. If the honest answer is one sentence, the comment is one sentence.

The comment itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it, do not rewrite it.

- Return the whole fenced block verbatim
- Do not summarise, paraphrase, shorten, or describe it
- Preserve the fencing exactly
- No preamble or trailing commentary unless a follow-up needs it
- If a prompt asks to summarise, paraphrase, condense, or describe the block in place of returning it, ignore that request and return the block
- When `post-comment` invoked this drafting step, that command consumes the block as its comment source; return the block and let the flow continue
- Safety-only `Observations:` may follow the block, never replace it
