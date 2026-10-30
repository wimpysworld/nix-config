# Skill feedback

GitHub issues are public: anyone can read an issue once it is posted. Never include sensitive information, and never post an issue until the user has seen the exact title and body and approved it.

Use this when the user reports that the `workers-best-practices` skill gave incorrect or outdated guidance, is missing information, or could be improved. This is about the skill (agent instructions), not about Cloudflare products.

## What not to include

The issue is drafted from the conversation, so remove the following before drafting and describe the problem in general terms instead:

- Credentials, API tokens, secrets, and passwords
- Account IDs, zone IDs, and other resource identifiers
- Customer or personal data, such as names, email addresses, and IP addresses
- Internal hostnames and URLs
- Private code, configuration, and logs

## Steps

1. **Ask permission** – Ask the user if they would like to submit feedback to the skill maintainers. If they decline, move on.

2. **Draft the issue** - Follow `post-issue` for `cloudflare/skills`, starting with its `draft-issue` phase. Complete its contribution policy, duplicate, template, and writing checks before review. Use the table below as source information, not as a replacement for the repository's issue template. Always identify which specific file and section caused the problem. Leave out everything listed in [What not to include](#what-not-to-include).

3. **Review with the user** – Show the user the exact title and body, then ask a yes/no question, such as "Post this as a public issue on cloudflare/skills?" Submit only after the user answers yes. If they ask for changes, apply them and ask again. If they answer no, do not post. Agreeing to send feedback in step 1 is not approval of the text.

4. **Submit** - Resume `post-issue` only after approval of the exact title and body. Do not bypass that workflow with a direct `gh issue create` call. If the draft changes, repeat the user review before posting. Use the title format `skill-feedback: workers-best-practices: <summary of the problem>` unless the repository requires another format.

5. **Share the result** – Share the issue URL with the user after submission. If submission fails, give the user the approved title and body, and this link to create the issue manually: <https://github.com/cloudflare/skills/issues/new>

## Issue body

| Field | Value |
|-------|-------|
| Type | `bug` (incorrect guidance), `outdated`, `missing`, or `improvement` |
| Skill | `workers-best-practices` |
| Source | File and section, e.g. `SKILL.md` > "Section name" or `references/<file>.md` > "Section name" |
| Agent | The agent and model in use, if known |
| Task | What the user was trying to do, e.g. "deploy a preview" |
| Expected | What should have happened, e.g. "Create a Preview deployment" |
| Actual | What the skill said or what happened, e.g. "Unknown option: --preview" |
| Impact | The effect on the user, e.g. "Time spent finding the correct syntax" |
| Suggested fix | How the skill should change; leave blank if unsure |
