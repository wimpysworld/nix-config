---
name: writing-well
description: "Use when drafting or revising a prose artefact: documentation, a README, a blog post, a technical guide, a migration guide, release notes, a video script, or long-form explanatory content. Covers composition principles (active voice, concrete language, omitting needless words, emphatic endings, parallel structure, keeping related words together) and the catalogue of AI writing patterns, including puffery, superficial '-ing' analysis, copulative avoidance, chatbot leakage, and overused vocabulary."
---

# Writing Well

## Scope

Load for prose artefacts: documentation, READMEs, blog posts, technical guides, migration guides, release notes, narrative and video scripts, and long-form explanatory content.

Do not load for routine operational output: sub-agent status, delegation responses, implementation reports, audit findings, code review findings, test summaries, command output relays, or ticket comments unless the user asks to polish prose.

## Relationship to the other layers

The generated Communication Rules govern vocabulary and brevity on every utterance and are hook-enforced. The `contribution-voice` skill governs the shape of short public text published under the user's name. This skill governs composition inside long-form artefacts.

The Communication Rules say to skip puffery, didactic disclaimers, and superficial '-ing' analysis without defining any of the three. The pattern catalogue below is where those terms are defined.

## Principles

Full comparison tables for each principle are in `reference.md`. Quoted examples keep Strunk's American spelling.

1. **Active voice.** "The team fixed the bug" not "The bug was fixed by the team." Cut perfunctory openers: *there is*, *there are*, *it was*. Strunk does not ban the passive: use it when the receiver of the action is the topic, or when the actor is unknown or unimportant.
2. **Positive form.** Say what is, not what isn't. "He usually came late" not "He was not very often on time."
3. **Concrete language.** Specific beats abstract. "It rained every day for a week" not "A period of unfavorable weather set in."
4. **Omit needless words.** Cut "the fact that", "in order to", "it should be noted that". A sentence needs no unnecessary words, a paragraph no unnecessary sentences.
5. **Keep related words together.** "Modifiers should come, if possible, next to the word they modify." "He found only two mistakes" not "He only found two mistakes". A stray *only* changes what an instruction orders.
6. **Emphatic endings.** Put the most important words last. The start of a sentence is the other strong position.
7. **Parallel structure.** Express co-ordinate ideas in similar form. Correlatives (both/and, not/but, either/or) take the same construction on each side. When parallelism turns unwieldy, Strunk's escape hatch is a table.
8. **Paragraph discipline.** One topic per paragraph. Open with a topic sentence, close in conformity with it, and vary sentence structure.
9. **One tense in summaries.** Pick present or past and hold it. Shifting tenses signals uncertainty.

## AI patterns

LLMs regress to statistical means, replacing rare specific facts with common inflated ones. Worked examples and full phrase lists are in `reference.md`. Sources and licence are credited there.

**These are observations, not proof.** Text showing them is not necessarily AI-generated; the models learned these habits from human writing, and a 2025 study found humans distinguish LLM text no better than chance. So fix the writing fault, do not accuse the text of being generated, and do not strip a legitimate word only because it appears on a list. Chatbot leakage is the one exception: it is evidence.

- **Puffery.** Claims about broader impact, legacy, or symbolism: "stands as a testament to", "marking a pivotal moment".
- **Superficial '-ing' analysis.** Participle phrases asserting empty significance: "ensuring reliability", "showcasing its capabilities". A person can highlight something; a railway station cannot.
- **Promotional language.** Grandiose sales copy: "nestled in the heart of", "boasts a", "stunning".
- **Copulative avoidance.** The strongest tell. Plain *is* and *are* replaced by *serves as*, *stands as*, *marks*, *functions as*, *represents*, *boasts*, *features*, *maintains*, *offers*. Worst in a README's opening sentence, where the honest line is "X is a Y that does Z."
- **Challenges and future prospects.** "Despite its [positives], [subject] faces challenges", then vague optimism. Remove the whole formula.
- **Formatting overuse.** Bold on every term, inline-header lists, emoji on headings, dashes where a comma would serve. A table carrying real data is not this pattern.
- **Markdown-level tells.** Title Case On Every Heading, and a thematic break before every heading. Both are checkable in our own output.
- **Synonym variance.** Cycling through synonyms to avoid repeating a word. Use the clearest term consistently.
- **False ranges.** "From X to Y" where no scale exists between the endpoints.
- **Rule of three.** "Adjective, adjective, and adjective" when one precise word would do.
- **Negative parallelisms.** "Not only X, but Y", "not just about X, it's about Y". Only when the contrast is genuine.
- **Didactic disclaimers** (dated tell, still a fault). "It's important to note", "it's worth mentioning". Delete them and state the fact.
- **Empty conclusions** (dated tell, still a fault). "In summary", "Overall", "In conclusion" followed by restatement. End on the last substantive point.

**Chatbot leakage** is proof, not probability. Check every artefact for `utm_source=openai`, `utm_source=chatgpt.com`, `referrer=grok.com`; for vendor markup such as `oaicite`, `citeturn0search0`, `[cite: 1]`, `grok_card`, `ppl-ai-file-upload`; and for chat text pasted into the file, such as "I hope this helps", "Certainly!", "Best regards, [Your Name]", `INSERT_SOURCE_URL_30`.

**Steer towards human writing:** plain *is* and *has*, short verbs (*wrote* not *authored*, *used* not *utilised*, *died* not *passed away*), specific odd detail, and uneven rhythm. Prose polished to a uniform sentence length reads as machine output.

**Banned words and phrases** - these are LLM tells:
pivotal, crucial, vital, testament, enduring legacy, indelible mark, nestled, in the heart of, groundbreaking, seamless, robust, cutting-edge, delve, leverage, multifaceted, foster, realm, tapestry, vibrant, nuanced, intricate, intricacies, interplay, landscape (figurative), garnered, underpinning, underscores, showcasing, streamline, aligns with

This list reflects roughly 2024-era models and decays with each generation; *delve* dropped off sharply in 2025. Read it as a signal about quality, not as identification.

## Before and after

<example_bad>
The configuration system plays a crucial role in ensuring seamless deployment
across environments, showcasing the framework's robust architecture and
highlighting its commitment to developer experience.
</example_bad>

<example_good>
The configuration system deploys consistently across environments.
</example_good>

<example_bad>
It's important to note that this feature leverages a multifaceted approach,
delving into the intricacies of the underlying architecture to foster a more
streamlined workflow.
</example_bad>

<example_good>
This feature reduces deployment steps from five to two.
</example_good>

## Reference

`reference.md` holds the full Strunk comparison tables for every principle above, the expanded AI pattern catalogue with complete phrase lists, and the source credits.
