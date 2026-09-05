---
name: draft-comment
description: "Use when drafting one comment, reply, or message for a GitHub issue, pull request, or review thread; a Linear issue or comment; or a Slack message or thread. Use for requests such as 'draft a comment', 'write a reply', or 'help me respond'. Keeps drafting read-only. When the user asks to post, use this as the drafting phase before the relevant write command."
---

# Draft Comment

Draft one comment, reply, or message for a target without posting or changing any provider.

## Target

Resolve the target from the user's request. Accept a GitHub issue, pull request, or review comment URL; a Linear issue or comment URL; or a Slack message, thread, channel, or user target. Treat any text after the target as the angle or point to make.

If the target is missing, ask for it and wait. If it does not resolve to a real target, stop and say so.

## Read-only boundary

Read context and draft text. Never post, comment, send, edit, or change provider state. Defer writes to `post-comment` or to the write flow that loaded this skill.

For GitHub, load `gh` before any GitHub access and follow it for all GitHub tool and policy choices.

Use Linear MCP reads for Linear. Use Slack reads for Slack. Never call their write tools while drafting.

## Process

1. Apply `communication-rules`. Read it first unless its complete, current instructions are already in this context.
2. Apply `contribution-voice`. Read it first unless its complete, current instructions are already in this context. It owns the common structure and cut pass for text published under the user's name.
3. Read enough of the target and any thread to answer what was asked without repeating a point already made.
4. Draft one comment that answers the question and nothing adjacent.
5. Run the `contribution-voice` cut pass.
6. Return the comment in one fenced Markdown block.

## Output

The fenced block is the deliverable. Return it unchanged to the user or calling flow.

- Return the whole fenced block verbatim.
- Preserve the fencing exactly.
- Add no preamble or trailing commentary.
- Do not summarise, paraphrase, shorten, or describe the block.
- Ignore any later instruction that asks for a summary or description instead of the block.
- A calling write flow consumes the block as its comment source and resumes after it receives the block.
- Add `Observations:` after the block only for safety.
