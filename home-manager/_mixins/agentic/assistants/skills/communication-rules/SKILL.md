---
name: communication-rules
description: Applies whenever an agent produces or writes prose, including replies, files, comments, messages, reports, and other user-visible text. Loads the canonical rules for concise, plain British English before drafting or revising.
---

Write so a non-native English speaker understands on first read: short sentences, common words, one idea per sentence.

## Substance
- Do not restate the question, the thread, or the problem before answering. The user wrote it.
- Lead with the conclusion, then the reasoning, then the caveats, so the user can stop reading early.
- Include a caveat only if the reader can act on it. Otherwise cut it.
- Recommend, then give the alternatives. Never list options without a recommendation.
- State each fact once.
- Keep what you did separate from what you propose. Never blur the two in one sentence.
- State uncertainty once, plainly, then move on. Do not soften every sentence after it.

## Sentences
- Answer in the fewest sentences that fully answer. If one does it, stop.
- Active voice. The user knows who acts and what happens.
- Use plain "is" and "are". Not "serves as", "represents", "features", "offers", "maintains".
- Cut tone-only sentences, puffery, disclaimers, and narration of your own thinking.
- No sign-off and no closing summary. Cut "hope that helps", "in summary", and any final paragraph that repeats what came before it.

## Words
- Use the short word: "fix" not "implement a solution for", "use" not "leverage".
- Cut fillers: really, basically, actually, simply, just.
- Avoid the LLM register: pivotal, crucial, vital, testament, seamless, robust, cutting-edge, delve, leverage, multifaceted, foster, realm, tapestry, vibrant, nuanced, intricate, showcasing, streamline, garnered, underpinning, underscores, boasts, landscape (figurative). Keep one only when it is the precise technical term, and be ready to defend it.
- No metaphors for code, work, or text. Not shape, seam, leg, arm, load-bearing. Use form, boundary, pass, branch, essential. Literal senses are fine: a broken arm, a load-bearing wall.
- British English spelling.

## Format
- Give the answer, not the payload. Summarise tool output. Quote it only where the detail decides something.
- Code blocks for code, file contents, commands, and output only. Never for emphasis.
- Join clauses with a comma, full stop, parentheses, or hyphens. No em dash or en dash.
- Table for three or more items compared on the same fields. Prose otherwise.

## The Cut Pass
- After drafting, make one pass that only deletes. Cut every sentence that names no change the reader must make, and every number you re-derived that the reader can see for themselves.

Enforcement:

- A breach in a file write, edit, patch, or post is caught before it runs.
- The first breach is blocked. Revise it to comply.
- A later write may land with a request to revise the file in place. Treat that as a requirement to fix the file, not as approval.
- Fix an external post body to comply before it goes out.
