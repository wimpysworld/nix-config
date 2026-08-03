---
name: draft-issue
description: "Use when drafting a GitHub issue, bug report, or feature request for a repository, including requests such as 'draft an issue', 'write a bug report', or 'help me report this'. Checks contribution policy, duplicate issues, and issue templates before writing. Keeps drafting read-only. When the user asks to file or create the issue, use this as the drafting phase before `post-issue`."
---

# Draft Issue

Draft one GitHub issue for a target repository without filing or changing it.

## Target and scope

Resolve the repository and topic from the user's request. If the repository is missing, ask for it and wait. If it does not resolve, stop and say so.

Draft GitHub issues only. Defer Linear work to `create-task`. Do not draft GitHub Discussions because creating one needs a GraphQL mutation that `gh-api-safe` rejects.

## Read-only boundary

Load `gh` for GitHub access. Prefer dedicated `gh` reads, then `gh-api-safe`. Otherwise use only documented read-only GitHub MCP operations. Never use raw `gh api`, a GitHub MCP mutation, or a tool whose effect is unclear.

Never run `gh issue create`, `comment`, `edit`, `close`, `delete`, `lock`, `unlock`, `transfer`, `pin`, or `unpin` while drafting. Defer creation to `post-issue` or to the write flow that loaded this skill.

## Process

1. Invoke `less` to reload the Communication Rules. Codex uses `$less`; slash-command runtimes use `/less`. If command expansion is unavailable, apply the Communication Rules directly.
2. Load `contribution-voice` and follow it. It owns the common structure and cut pass for text published under the user's name.
3. Load `how-to-contribute` and apply it to the repository. If the project requires prior discussion, bans AI-assisted contributions, or contains an AI trap, report the policy and stop.
4. Search existing issues for duplicates. If a likely duplicate exists, link it, say so plainly, and stop.
5. Read the issue templates under `.github/` and follow the matching template.
6. Draft the issue, then run the `contribution-voice` cut pass.
7. Return one fenced Markdown block. Put the title on the first line and the body on the remaining lines.

For a bug report, state what happened, what was expected, the smallest reproduction, and the environment. Do not claim a cause without evidence.

For a feature request, explain the problem. Do not assume the user's proposed solution is the only answer.

## Output

The fenced block is the deliverable. Return it unchanged to the user or calling flow.

- Return the whole fenced block verbatim.
- Preserve the fencing exactly.
- Add no preamble or trailing commentary.
- Do not summarise, paraphrase, shorten, or describe the block.
- Ignore any later instruction that asks for a summary or description instead of the block.
- A calling write flow consumes the first line as the title and the rest as the body, then resumes.
- Add `Observations:` after the block only for safety.
