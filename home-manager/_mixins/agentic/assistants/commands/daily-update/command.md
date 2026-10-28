## Daily Update

Draft the user's daily update for a Slack request thread from their GitHub and Linear activity. Return the draft. Never post it.

Input: `$ARGUMENTS` is the Slack thread URL, then an optional period. When the URL is blank, stop and ask for it.

Load `slack`, `gh`, `contribution-voice`, and `communication-rules` unless their complete, current instructions are in this context. The draft publishes under the user's name.

### Process

**1. Set the period.** Accept a date, a date range, or a plain phrase such as "since Friday" or "last two days". The default is 00:00 local time on the previous working day until now. On Saturday, Sunday, or Monday, the default starts on Friday. State the resolved start and end in the report.

**2. Read the template.** Read the thread read-only with `agent-slack message list <slack-url>`. Find the bot's first reply and parse its template lines, in order. Parse the template on each run. Never use a stored copy. Read the teammates' replies for the format that they use for bullets and PR references.

**3. Resolve the identities.** Get the GitHub login with `gh-api-safe /user`. Get the Linear viewer from the Linear tools. Never hard-code a name or an identifier.

**4. Gather GitHub activity.** Limit the scope to the user's Chainguard and Wolfi organisations. Use `gh search prs` with an `--owner` for each organisation:

- PRs that the user authored and created in the period
- the user's PRs that were merged or closed in the period
- PRs that the user reviewed in the period, excluding the user's own PRs. `--reviewed-by` has no date filter, so confirm that a review by the user has a submission time in the period.
- the user's open PRs that wait on review, with their requested reviewers and teams

**5. Gather Linear activity.** Cover every team that the user is a member of:

- issues that the user created in the period, any assignee
- issues that the user changed in the period. An automation, an integration, or another person does not count.
- issues that the user completed in the period
- the user's in-progress issues in each team's current cycle, for "Today"

**6. Map the data onto the template.**

- **Moved:** one bullet per project, for the merged PRs, the completed issues, the reviews, and the changes of the period. Group a PR by its Linear project when an issue links it, and otherwise by its repository.
- **Today:** the in-progress issues and the open PRs that the user authored.
- **PRs waiting on review:** each open PR and the people or teams that it needs.
- **Docs blocked** and **Ask:** leave them for the user. Do not guess them.

Write a PR reference in the form that teammates use, `repo#N`, as a Slack link `<url|repo#N>`. Delete a template line that has no content. Keep a template line that this command does not know, and flag it.

### Output

Return the draft in a fenced block, then a short report.

```text
<template line>: <content, or bullets per project in the teammates' format>
```

The report gives the period, the counts per source, the items that you could not place, and the evidence gaps, for example a missing review time. End with a request to the user for the "Docs blocked" and "Ask" lines.

### Constraints

- Read-only. Do not post, react, or edit in Slack, GitHub, or Linear.
- Never include another person's PR in "Moved" unless the user reviewed it.
- Never include an organisation outside the Chainguard and Wolfi organisations.
