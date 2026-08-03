## Draft Comment

Draft one comment for an existing thread. This step drafts only; it never posts or mutates any surface.

Target argument: $ARGUMENTS. This is the thread URL, optionally followed by the angle or point the user wants to make. If $ARGUMENTS is blank, ask which thread and wait.

The thread URL may be a GitHub issue, pull request, or review comment; a Linear issue or comment; or a Slack message or thread.

### Read-only boundary

This command reads context and drafts text. It never posts or mutates a provider. `post-comment` is the write path for this flow.

For GitHub thread and context retrieval, follow the global GitHub read rule: prefer dedicated `gh` reads, then `gh-api-safe`; otherwise use only documented, clearly read-only GitHub MCP operations. Never use a GitHub MCP mutation or a tool whose effect is unclear. Never call Linear or Slack write tools while drafting.

### Process

1. Invoke `less` to reload the Communication Rules before drafting. Codex uses `$less`; slash-command runtimes use `/less`. If the platform cannot expand a command, apply the rules restated below instead
2. Load the `contribution-voice` skill and follow it. It governs the structure of text published under the user's name
3. Read the thread before writing. Apply the read-only boundary above for GitHub, use Linear MCP reads for Linear, and use Slack reads for Slack. Read enough of the thread to answer what was asked, including what others already said, so the comment does not repeat an existing point
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
