---
name: writing-clearly-and-concisely
description: Core writing rules for clear, concise prose. Load when writing any text a human will read.
---

# Writing Clearly and Concisely

## Principles

Apply to all prose: documentation, commit messages, reports, explanations, UI text.

1. **Active voice.** "The team fixed the bug" not "The bug was fixed by the team." Active is shorter, clearer, stronger.
2. **Positive form.** Say what is, not what isn't. "He usually came late" not "He was not very often on time."
3. **Concrete language.** Specific beats abstract. "It rained every day for a week" not "A period of unfavourable weather set in."
4. **Omit needless words.** Every sentence earns its place. Cut "the fact that", "in order to", "it should be noted that", "there is/are". A sentence needs no unnecessary words, a paragraph no unnecessary sentences.
5. **Emphatic endings.** Place the most important word or phrase at the end of the sentence.
6. **Parallel structure.** Express co-ordinate ideas in similar form.

## AI Patterns to Avoid

LLMs regress to statistical means, producing generic, inflated prose. Recognise and eliminate:

**Banned words and phrases** - these are LLM tells:
pivotal, crucial, vital, testament, enduring legacy, indelible mark, nestled, in the heart of, groundbreaking, seamless, robust, cutting-edge, delve, leverage, multifaceted, foster, realm, tapestry, vibrant, nuanced, intricate, intricacies, interplay, landscape (figurative), garnered, underpinning, underscores, showcasing, streamline, aligns with

**Banned patterns:**
- Superficial "-ing" analysis: "ensuring reliability", "highlighting its importance", "showcasing features", "reflecting broader trends"
- Puffery about significance: "plays a vital role", "stands as a testament", "marking a pivotal moment"
- Didactic disclaimers: "it's important to note", "it's worth mentioning"
- Empty conclusions: "In summary", "Overall", "In conclusion" followed by restatement
- Rule of three for padding: "adjective, adjective, and adjective" when one would do
- Negative parallelisms: "not just X, but Y" and "not only X, but also Y"

## Before and After

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

## Heavy Reference

For extended writing tasks (documentation, blog posts, technical guides), load `prose-style-reference` for the full Strunk composition rules and expanded AI pattern catalogue.
