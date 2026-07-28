# Writing Well Reference

Heavy reference. The body is `SKILL.md`.

## Contents

- [Part 1: Composition Principles (Strunk)](#part-1-composition-principles-strunk)
- [Part 2: AI Writing Patterns](#part-2-ai-writing-patterns)
- [Part 3: Local Additions](#part-3-local-additions)

## Part 1: Composition Principles (Strunk)

Based on William Strunk Jr.'s *The Elements of Style* (1918), which is public domain. Quoted cells keep Strunk's American spelling; our own prose uses British spelling.

### Active Voice

The active voice is more direct and vigorous than the passive. Strunk credits George McLane Wood for material in this rule.

| Passive | Active |
|---------|--------|
| My first visit to Boston will always be remembered by me. | I shall always remember my first visit to Boston. |
| A survey of this region was made in 1900. | This region was surveyed in 1900. |
| There were a great number of dead leaves lying on the ground. | Dead leaves covered the ground. |
| The sound of a guitar somewhere in the house could be heard. | Somewhere in the house a guitar hummed sleepily. |
| It was not long before he was very sorry that he had said what he had. | He soon repented his words. |

Eliminate perfunctory expressions: *there is*, *there are*, *it was*, *could be heard*. Replace with verbs that do work.

Strunk's own caveat, verbatim: "This rule does not, of course, mean that the writer should entirely discard the passive voice, which is frequently convenient and sometimes necessary."

Use the passive when the receiver of the action is the topic of the paragraph, or when the actor is unknown or unimportant. In technical writing the system is often the topic, not the operator: "The unit is rebuilt on every switch" is correct when the unit is what the paragraph is about.

### Positive Form

Make definite assertions. Use *not* for denial or antithesis, never evasion.

| Negative evasion | Positive form |
|------------------|---------------|
| He was not very often on time. | He usually came late. |
| did not remember | forgot |
| did not pay any attention to | ignored |
| did not have much confidence in | distrusted |
| not important | trifling |

The reader wants to be told what *is*, not what *is not*.

### Concrete Language

Prefer the specific to the general, the definite to the vague.

| Abstract | Concrete |
|----------|----------|
| A period of unfavorable weather set in. | It rained every day for a week. |
| He showed satisfaction as he took possession of his well-earned reward. | He grinned as he pocketed the coin. |
| In proportion as the manners, customs, and amusements of a nation are cruel and barbarous, the regulations of their penal code will be severe. | In proportion as men delight in battles, bull-fights, and combats of gladiators, will they punish by hanging, burning, and the rack. |

The penal-code pair is Strunk quoting Herbert Spencer, *Philosophy of Style*.

The surest way to hold the reader's attention is to be specific, definite, and concrete.

### Omit Needless Words

A sentence should contain no unnecessary words, a paragraph no unnecessary sentences, for the same reason that a drawing should have no unnecessary lines and a machine no unnecessary parts.

| Wordy | Concise |
|-------|---------|
| the question as to whether | whether |
| there is no doubt but that | doubtless |
| used for fuel purposes | used for fuel |
| he is a man who | he |
| in a hasty manner | hastily |
| owing to the fact that | since |
| in spite of the fact that | though |
| call your attention to the fact that | remind you |
| the fact that he had not succeeded | his failure |

Revise *the fact that* out of every sentence. Eliminate *who is*, *which was* when superfluous:

| Wordy | Concise |
|-------|---------|
| His brother, who is a member of the same firm | His brother, a member of the same firm |
| Trafalgar, which was Nelson's last battle | Trafalgar, Nelson's last battle |

Combine step-by-step presentation of a single idea into one sentence:

| 51 words | 26 words |
|----------|----------|
| Macbeth was very ambitious. This led him to wish to become king of Scotland. The witches told him that this wish of his would come true. The king of Scotland at this time was Duncan. Encouraged by his wife, Macbeth murdered Duncan. He was thus enabled to succeed Duncan as king. | Encouraged by his wife, Macbeth achieved his ambition and realized the prediction of the witches by murdering Duncan and becoming king of Scotland in his place. |

### Keep Related Words Together

"Modifiers should come, if possible, next to the word they modify." Word order carries meaning, so a stray modifier changes what an instruction says.

| Misplaced | Correct |
|-----------|---------|
| He only found two mistakes. | He found only two mistakes. |
| All the members were not present. | Not all the members were present. |
| He noticed a large stain in the rug that was right in the center. | He noticed a large stain right in the center of the rug. |

*Only* is the frequent offender in technical prose. "Only run this on a laptop" and "run this only on a laptop" give different orders.

### Emphatic Endings

Place the most important words at the end of the sentence.

| Weak ending | Strong ending |
|-------------|---------------|
| Humanity has hardly advanced in fortitude since that time, though it has advanced in many other ways. | Humanity, since that time, has advanced in many other ways, but it has hardly advanced in fortitude. |
| This steel is principally used for making razors, because of its hardness. | Because of its hardness, this steel is principally used in making razors. |

The beginning of a sentence is the other strong position. Any element other than the subject becomes emphatic when placed first: "Deceit or treachery he could never forgive."

### Parallel Structure

Express co-ordinate ideas in similar form.

| Broken parallel | Parallel |
|-----------------|----------|
| Formerly, science was taught by the textbook method, while now the laboratory method is employed. | Formerly, science was taught by the textbook method; now it is taught by the laboratory method. |
| It was both a long ceremony and very tedious. | The ceremony was both long and tedious. |
| A time not for words, but action. | A time not for words, but for action. |

Correlative expressions (both/and, not/but, either/or) must be followed by the same grammatical construction.

**The table escape hatch.** Strunk allows the writer to step out of prose when parallelism turns unwieldy: "he had best avoid difficulty by putting his statements in the form of a table." Twenty parallel sentences are worse than one table. Read this together with the formatting-overuse pattern in Part 2: a table that carries real data earns its place, decorative structure does not.

### Paragraph Discipline

- One paragraph per topic.
- "As a rule, begin each paragraph with a topic sentence; end it in conformity with the beginning."
- Vary sentence structure to avoid monotonous loose-sentence chains.

Strunk exempts short-form work: "textbooks, guidebooks, and other works in which many topics are treated briefly" may use single-sentence paragraphs. Documentation and README prose fall under that exemption.

### One Tense in Summaries

When summarising, choose present or past tense and hold it throughout. Shifting tenses signals uncertainty.

---

## Part 2: AI Writing Patterns

Part 2 adapts material from [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing), used under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

LLMs regress to statistical means. Specific and unusual facts (statistically rare) are replaced with generic, inflated descriptions (statistically common). The subject becomes simultaneously less specific and more exaggerated.

### How to read this catalogue

These are observations, not proof. The source states the position plainly: "this list is descriptive, not prescriptive; it consists of observations, not rules." It also reports that "a 2025 study has shown that human ability to distinguish LLM text from human is no better than random chance."

Text carrying these signs is not necessarily AI-generated. The models learned every one of these habits from human writing, so a human writer produces them too.

The practical consequence for our work:

- Fix the writing fault. Do not accuse the text, or its author, of being generated.
- Do not strip a legitimate word only because it appears on a list. *Crucial* is the right word when something is genuinely essential; *vital* is the right word about organs.
- Weigh the whole passage, not the single hit. One tell means little, six in a paragraph mean something.
- Chatbot leakage is the exception. It is evidence, not probability. See below.

The vocabulary lists reflect roughly 2024-era models and decay with each generation. The source notes that *delve* "dropped off sharply in 2025". Treat the words as a signal about quality, never as an identification.

### Puffery and Inflated Importance

LLMs puff up significance by attaching claims about broader impact, legacy, or symbolism:

- "marking a pivotal moment in the evolution of..."
- "stands as a testament to..."
- "plays a vital/significant/crucial/pivotal role"
- "underscores/highlights its importance/significance"
- "reflects broader trends in..."
- "symbolising its ongoing/enduring/lasting impact"
- "deeply rooted", "profound heritage", "steadfast dedication"
- "indelible mark", "key turning point"

These statements are synthesis: a disembodied narrator claiming what something *means* rather than stating what it *does*.

### Superficial "-ing" Analysis

Attaching present participle phrases to make empty claims about significance:

- "ensuring reliability across deployments"
- "highlighting the importance of community engagement"
- "showcasing the framework's capabilities"
- "reflecting a commitment to innovation"
- "underscoring the need for further research"

Stronger tell: when the subject of these verbs is a fact, event, or inanimate thing.

### Promotional Language

- "continues to captivate", "stunning natural beauty"
- "groundbreaking" (figurative), "cutting-edge"
- "nestled", "in the heart of", "boasts a"
- "seamless", "robust", "streamlined"

Say what it does. Be specific, not grandiose.

### Copulative Avoidance

The strongest linguistic tell in the catalogue. LLMs shy away from plain *is* and *are*, and reach for a heavier verb that adds nothing. One cited study found the use of *is* and *are* in academic writing fell by over 10% in 2023.

Watch for: *serves as*, *stands as*, *marks*, *functions as*, *represents*, *boasts*, *features*, *maintains*, *offers*.

| Inflated | Plain |
|----------|-------|
| `foo` serves as a wrapper around `bar`. | `foo` wraps `bar`. |
| The module functions as the entry point. | The module is the entry point. |
| The repository boasts 40 packages. | The repository has 40 packages. |
| This release represents a fix for the parser. | This release fixes the parser. |

This lands hardest on the opening sentence of a README, where the writer is under pressure to sound impressive and the honest sentence is "X is a Y that does Z."

### Overused AI Vocabulary

Words that co-occur heavily in LLM output. Where there is one, expect others:

aligns/aligning with, crucial, delve/delving, emphasising, enduring, enhance/enhancing, fostering, garnered/garnering, highlight/highlighting (as verb), interplay, intricate/intricacies, key (adjective), landscape (figurative), leveraging, multifaceted, nuanced, pivotal, realm, robust, seamless/seamlessly, shed light on, showcasing, streamline, tapestry, testament, underpinning, underscores/underscoring, vibrant, vital

`SKILL.md`'s banned list is this list plus the promotional phrases above.

*Notably* is deliberately absent. The source files it under ineffective indicators: it is common in human writing too, so it is not a strong tell and not banned.

### Signs of Human Writing

A positive target, not only a list to avoid. Human prose more often:

- Uses plain *is* and *has* where an LLM reaches for *serves as* or *features*.
- Picks the short verb: *wrote* not *authored*, *used* not *utilised*, *died* not *passed away*, *built* not *constructed*.
- Names the specific and the odd, including detail no summariser would keep.
- Tolerates wordy constructions and uneven rhythm. Human writing is allowed to ramble a little; LLM writing is uniformly smooth.

The last point matters when revising. Tightening prose until every sentence is the same length reads as machine output, even when a human wrote it.

### Chatbot Leakage

Unlike the rest of this catalogue, these are proof rather than probability: "LLM output sometimes exposes its internal formatting code, which is an unambiguous indicator that the text originated with AI."

**Tracking parameters on URLs**

`utm_source=openai`, `utm_source=chatgpt.com`, `utm_source=copilot.com`, `referrer=grok.com`

**Internal markup, by vendor**

| Vendor | Markers |
|--------|---------|
| ChatGPT | `oaicite`, `citeturn0search0`, `contentReference` |
| Gemini | `[cite: 1]` |
| Grok | `grok_card` |
| Perplexity | `ppl-ai-file-upload` |

**Correspondence pasted into the artefact**

Text addressed to the user that belongs in the chat, not the file: "I hope this helps", "Of course!", "Certainly!", "You're absolutely right!", "is there anything else", "let me know".

Unfilled placeholders count too: "Best regards, [Your Name]", `INSERT_SOURCE_URL_30`.

Check our own output for all three before it ships.

### Markdown-Level Tells

- AI chatbots strongly tend to capitalise all main words in section headings. Follow the convention the document already uses rather than switching to Title Case mid-file.
- Some place a thematic break (`---`) before every heading. A heading already separates sections.

### Formatting Overuse

- Excessive boldface on every key term
- Inline-header vertical lists (bold header + colon + description)
- Emoji decorations on headings or bullets
- Em dash overuse in place of commas, parentheses, or colons

A table is the exception, not an instance of this pattern. See the table escape hatch in Part 1.

### Synonym Variance

LLMs avoid repeating words by cycling through synonyms. Prefer natural repetition over forced variation. Use the clearest term consistently.

### Rule of Three

LLMs overuse triplets: "adjective, adjective, and adjective" or "short phrase, short phrase, and short phrase." One precise word beats three vague ones.

### Negative Parallelisms

"Not only X, but Y" and "It is not just about X, it's about Y", common in LLM output, often unsuitable for neutral tone. Use sparingly and only when the contrast is genuine.

### Historical Indicators

The source now files the two patterns below as historical: common in models from November 2022 to 2024, much less frequent since. They remain writing faults worth fixing, but they are weak evidence of AI authorship today.

**Didactic disclaimers** (dated tell, still a fault)

- "it's important/critical/crucial to note/remember/consider"
- "may vary", "it's worth mentioning"

Delete these. If the information matters, state it directly. The generated Communication Rules ban them outright, so this one is enforced on us regardless of its age.

**Empty conclusions** (dated tell, upstream renamed "Section summaries")

- "In summary...", "In conclusion...", "Overall..."
- Restating what was already said

End with the last substantive point, not a summary of it.

---

## Part 3: Local Additions

Original to this skill. These are not from the sources credited in Part 1 or Part 2, and the CC BY-SA credit does not cover them.

### False Ranges

"From X to Y" constructions where no meaningful scale exists between the endpoints. LLMs use these to sound comprehensive. If you cannot identify a coherent middle ground, the range is false.

### The Animacy Test for "-ing" Analysis

A person can highlight something; a railway station cannot. When the subject of *highlighting*, *showcasing*, or *underscoring* is a fact, an event, or a thing, the clause is asserting significance nobody claimed. Cut it.

### Synonym Variance in Practice

The tell is a single referent named three ways in one paragraph: protagonist, key player, eponymous character. Pick one name and repeat it.
