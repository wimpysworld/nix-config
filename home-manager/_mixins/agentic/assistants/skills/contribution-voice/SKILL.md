---
name: contribution-voice
description: "Use when drafting text that is published under the user's name in public: a GitHub, Linear, or Slack comment, an issue, a bug report, a pull request description, a review reply, or a commit message. Governs the structure of the text (length, layout, sign-offs, the cut pass) rather than its vocabulary. Use even if the user only says 'reply to this issue', 'write the PR description', or 'draft a comment'."
user-invocable: true
---

# Contribution Voice

This text is published under the user's name, in public, next to their reputation. Maintainers have grown cautious and reject contributions that read as AI-generated on sight, whatever their technical merit. Many readers do not speak English as a first language, so short plain sentences serve them.

The Communication Rules govern vocabulary and grammar, and every agent already carries them in its system prompt. This skill adds what they do not cover: structure. Structure is the real tell. A reader spots generated text by a three-line point wrapped in headings and bullets, long before they notice a single word.

## Rules

**Stay inside the budget.** Every artefact has one. Length is the rule that gets abandoned first, so it is stated as a number, not as a preference.

| Artefact | Budget |
| --- | --- |
| Comment, reply, bug report | 1 to 3 sentences |
| Review, per finding | 3 sentences: the defect, the proof, the fix |
| Review, whole body | the findings and nothing else |
| Slack message | 1 to 2 sentences |
| Pull request description | 1 paragraph, plus 1 sentence of validation |
| Commit message | subject, plus a short paragraph or up to 5 bullets |
| Task or issue body | the template's sections, each one prose and not an essay |
| Handover or briefing | the word range its command states |

Over budget is a defect, not a style preference. Cut until it fits. If it will not fit, the draft is carrying content that does not belong to this artefact.

**No scaffolding.** Write prose. No headings, no bullet lists, no bold labels, no tables. Structure on a small point is the clearest sign of generated text, and it does not stop being one because the point got longer. The exception is a template that fixes the headings, such as a task body: there the template owns the layout and this skill governs the prose inside it.

**Answer only what was asked.** Do not pre-empt questions nobody asked. Do not attach adjacent advice.

**No emoji as section markers.** One emoji inside a sentence, where a human would use one, is fine. A column of emoji headings is not.

**Vary the structure.** Consecutive messages built on an identical skeleton read as generated, even when each one is fine alone.

## The Cut Pass

The house-style cut pass applies here too, and it is mandatory. Removing words is what makes text read as human; polishing adds them.

These items survive a careless pass, so cut them by name:

- The second and later examples of the same defect. One instance proves it.
- Any statement that something is correct, fine, unaffected, or holds. Silence says that.
- Any aside that occurred to you but was not asked about.

These are the audit trail: proof that you did the work. It belongs in the report, or nowhere. Nobody reading a comment wants evidence of your diligence, and including it is how a three-point answer becomes five hundred words.

Then count against the budget. Over budget means the pass is not finished.

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
