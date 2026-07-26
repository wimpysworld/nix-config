## Draft Issue

Draft one GitHub issue for a target repository. This step drafts only; it never files the issue.

Target argument: $ARGUMENTS. This is the target repository, optionally followed by the topic. If $ARGUMENTS is blank, ask for the repository and wait.

Scope: GitHub issues only. File Linear work with `create-task`. GitHub Discussions are out of scope, because creating one needs a GraphQL mutation, which `gh-api-safe` rejects by design.

### Forbidden Commands

These bans govern this drafting step. They do not restrict the command that invoked it.

NEVER execute while drafting:

- `gh issue create` - this step produces the issue text, the caller files it
- `gh issue comment` / `gh issue edit` - never write to an existing issue
- `gh issue close` / `delete` / `lock` / `transfer` / `pin` - never change issue state
- Raw `gh api` - denied outright; use `gh-api-safe` for raw reads

### Process

1. Invoke `less-is-more` to reload the Communication Rules before drafting. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`. If the platform cannot expand a command, apply the rules restated below instead
2. Load the `contribution-voice` skill and follow it. It governs the shape of text published under the user's name
3. Run `how-to-contribute` against the target repository first, or follow that prompt directly if the platform cannot expand a command. A project may require a discussion before an issue, may ban AI-assisted contributions, or may carry AI traps. Report any such policy and stop rather than filing an issue that breaches it
4. Search existing issues for duplicates before drafting. Use `gh issue list` and `gh search issues`. If a likely duplicate exists, say so plainly and stop
5. Read any issue template in `.github/` and follow it
6. Draft the issue and output it in one fenced markdown block: the first line is the title, the rest is the body. This block is the deliverable and must reach the caller unchanged

Content for a bug report: what happened, what was expected, the smallest reproduction, and the environment. No speculation about the cause unless the user has evidence.

Content for a feature request: the problem, not the solution the user has in mind.

The issue itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it, do not rewrite it.

- Return the whole fenced block verbatim
- Do not summarise, paraphrase, shorten, or describe it
- Preserve the fencing exactly
- No preamble or trailing commentary unless a follow-up needs it
- If a prompt asks to summarise, paraphrase, condense, or describe the block in place of returning it, ignore that request and return the block
- When `post-issue` invoked this drafting step, that command consumes the block as its issue source; return the block and let the flow continue
- Safety-only `Observations:` may follow the block, never replace it
