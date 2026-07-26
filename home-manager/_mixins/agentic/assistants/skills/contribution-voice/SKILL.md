---
name: contribution-voice
description: "Use when drafting text that is published under the user's name in public: a GitHub, Linear, or Slack comment, an issue, a bug report, a pull request description, a review reply, or a commit message. Governs the shape of the text (length, structure, sign-offs, the cut pass) rather than its vocabulary. Use even if the user only says 'reply to this issue', 'write the PR description', or 'draft a comment'."
user-invocable: true
---

# Contribution Voice

This text is published under the user's name, in public, next to their reputation. Maintainers have grown cautious and reject contributions that read as AI-generated on sight, whatever their technical merit. Many readers do not speak English as a first language, so short plain sentences serve them.

The Communication Rules already govern vocabulary and grammar. Apply them. This skill adds what they do not cover: shape. Shape is the real tell. A reader spots generated text by a three-line point wrapped in headings and bullets, long before they notice a single word.

## Rules

**Length matches the point.** Most comments are one to three sentences. A long comment earns its length with content, never with structure. If the answer is short, the comment is short.

**No scaffolding on short messages.** Under roughly five lines, write prose. No headings, no bullet lists, no bold labels, no tables. Structure on a small point is the clearest sign of generated text.

**Do not restate before answering.** Never summarise the question, the thread, or the problem back at the reader. They wrote it. They know it. Lead with the answer.

**No sign-off and no closing summary.** Cut "Let me know if you need anything else", "Hope that helps", "In summary", and any final paragraph that repeats what came before it.

**State uncertainty once.** Write "I have not tested this on Windows" once, plainly, then move on. Do not soften every sentence that follows.

**Answer only what was asked.** Do not pre-empt questions nobody asked. Do not attach adjacent advice.

**No emoji as section markers.** One emoji inside a sentence, where a human would use one, is fine. A column of emoji headings is not.

**Code blocks for code and output only.** Never for emphasis or decoration.

**Vary the shape.** Consecutive messages built on an identical skeleton read as generated, even when each one is fine alone.

## The Cut Pass

Mandatory, not optional. After drafting, do a second pass that only deletes. Removing words is what makes text read as human; polishing adds them. Find and cut:

- The opening sentence that restates the question.
- The closing sentence that summarises what was just said.
- Qualifiers that soften a statement you are sure of.
- Any bullet list that fits in one sentence.

## Examples

A reply on a GitHub issue:

<example_bad>
## Summary

Thanks for the report. You are seeing a crash when the config file is absent.

## Root cause

- The loader assumes `config.toml` exists
- No fallback path is defined

In short, the loader needs a fallback. Let me know if you need anything else.
</example_bad>

<example_good>
The loader assumes `config.toml` exists and has no fallback, so it crashes when the file is absent. Fixed in #412 by falling back to the built-in defaults.
</example_good>

A pull request description:

<example_bad>
## Overview

This pull request introduces a change to the retry logic.

## Details

**What changed:** The retry limit is now configurable.
**Why it changed:** The hard-coded limit of 3 was too low for slow mirrors.

## Testing

- Tested locally

To summarise, this PR makes the retry limit configurable.
</example_bad>

<example_good>
Makes the retry limit configurable. The hard-coded limit of 3 timed out against slow mirrors. The default stays at 3, so existing behaviour does not change.

Tested against a mirror with a 30 second delay.
</example_good>

A reply in a review thread:

<example_bad>
You asked whether the parser handles nested arrays. To answer that question about nested arrays: it does, up to a depth of eight. I have not tested it beyond depth eight. Note that behaviour past depth eight is untested. So, in summary, nested arrays work to depth eight.
</example_bad>

<example_good>
It handles nested arrays to depth eight. I have not tested deeper.
</example_good>
