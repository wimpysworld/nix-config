# Catppuccin slide layouts

Use one layout and one palette on each slide. The theme name is `catppuccin-slides` throughout the deck.

## Setup

Start with `starters/latte.md`, `starters/mocha.md` or `starters/mixed.md`. Keep this frontmatter once, at the start:

```yaml
---
marp: true
theme: catppuccin-slides
size: 16:9
paginate: true
header: 'Team / Talk title'
footer: 'Presenter name · Event date'
---
```

Register `theme/catppuccin.css` with Marp. Enable HTML for these trusted templates because columns and captions use HTML wrappers.

Separate slides with `---`. Use `_class`, not `class`, for each slide. Always include `latte` or `mocha` with the layout class.

For dark variants, replace `latte` with `mocha` in the examples below. Do not repeat or change the global `theme` directive.

Keep blank lines around Markdown inside HTML wrappers. Use local image files and preserve their paths relative to the deck.

Use `Work Sans` for body text and `FiraCode Nerd Font Mono` for code. The theme does not fetch fonts or images.

## Layout selection

| Layout | Use | Content limit |
| --- | --- | --- |
| Opening | Establish the purpose | One title, one sentence |
| Agenda | Set the route | Three or four items |
| Section | Mark a transition | One short title |
| Statement | Make one claim | One claim, one qualifier |
| Two-column | Explain related ideas | Two short groups |
| Comparison | Compare equal criteria | Three rows |
| Evidence | Explain one result | One measure, its limits, its source |
| Visual | Show an image at full size | One caption |
| Metrics | Show exact values | Four rows |
| Process | Explain order or time | Four steps |
| Code | Explain a small example | Ten lines, about 70 characters per line |
| Architecture | Explain a request path | Three nodes and one boundary |
| Quote | Present a verified voice | About 30 words and attribution |
| Closing / appendix | Request action or support detail | One next action, or four reference items |

## Opening

```markdown
<!-- _class: latte opening -->
<!-- _paginate: false -->

<p class="eyebrow">Topic / Audience</p>

# Make the decision clear

<p class="lede">Explain why the audience needs to act.</p>
```

## Agenda

```markdown
<!-- _class: latte agenda -->

# The route to the decision

1. Define the problem
2. Read the evidence
3. Compare the options
4. Agree the next action
```

## Section

```markdown
<!-- _class: latte section -->

<p class="eyebrow">01 / Evidence</p>

# Test the claim

Name the question that follows.
```

## Statement

```markdown
<!-- _class: latte statement -->

# Reduce the work,<br>not the **confidence**

Add one condition or limit to the claim.
```

## Two-column

```markdown
<!-- _class: latte two-column -->

# Match the response to the problem

<div class="columns">
<div>

## Problem

Describe the constraint.

- Name its cost.
- Name who it affects.

</div>
<div>

## Response

Describe one bounded change.

- Name the owner.
- Name the measure.

</div>
</div>
```

## Comparison

```markdown
<!-- _class: latte comparison -->

# Compare the same criteria

| Criterion | Current | Proposed |
| :--- | :--- | :--- |
| Effort | Add a value | Add a value |
| Risk | State the risk | State the risk |
| Owner | Name the owner | Name the owner |

<p class="source">Source: title, date and link.</p>
```

## Evidence

```markdown
<!-- _class: latte evidence -->

# State one measured result

<div class="columns">
<div>

<p class="metric">00%</p>

Replace with a verified measure.

</div>
<div>

## What the result means

Define the sample and the baseline.

Explain the limits of the evidence.

</div>
</div>

<p class="source">Source: title, date, sample and link.</p>
```

## Visual

Copy `images/blue-study.svg` beside the deck in an `images/` directory, or use an approved local image. Adjust the path accordingly.

```markdown
<!-- _class: latte visual -->
<!-- _paginate: false -->

![bg cover](images/blue-study.svg)

<div class="caption">

# State the visual conclusion

Describe the meaning, not only the appearance.

<p class="source">Image: creator, source and licence.</p>

</div>
```

The opaque caption preserves text contrast. `cover` crops the image. Use `bg contain` when the whole image must remain visible.

Marp backgrounds are decorative. Put essential image information in visible text and speaker notes. Do not use this layout for dense charts.

## Metrics

```markdown
<!-- _class: latte metrics -->

# Give the values clear units

| Measure | Baseline | Current |
| :--- | ---: | ---: |
| Time | 00 min | 00 min |
| Count | 00 | 00 |
| Cost | £00 | £00 |

<p class="source">Replace all values. Define the period and sample.</p>
```

## Process / timeline

```markdown
<!-- _class: latte process -->

# Four steps, one review point

1. **Define**<br>Agree the question.
2. **Build**<br>Test one small change.
3. **Measure**<br>Compare the result.
4. **Decide**<br>Continue, revise or stop.
```

For a timeline, replace the bold step names with dates. Keep four steps or split the sequence across slides.

## Code

````markdown
<!-- _class: latte code -->

# Explain one operation

```python
from statistics import median

samples = [32, 34, 36]
print(median(samples))
```

<p class="source">Python · Example only · Explain inputs and output.</p>
````

Syntax uses weight and readable text colours. Do not apply an external syntax theme without a contrast check.

## Architecture

```markdown
<!-- _class: latte architecture -->

# Show the request direction

1. **1. Client**<br>Sends the request.
2. **2. Service**<br>Validates the input.
3. **3. Store**<br>Saves the result.

<p class="boundary">Trust boundary: validate client input before each write.</p>

<p class="source">Example flow. Describe any omitted dependencies in the notes.</p>
```

Use a local SVG with a visible description for a more complex architecture. Do not compress a full system into three boxes.

## Quote

```markdown
<!-- _class: latte quote -->

<p class="eyebrow">A voice from the review</p>

> “Replace with an exact, verified quotation.”

<p class="source">Name · Role · Source · Date</p>
```

## Closing / appendix

```markdown
<!-- _class: latte closing -->

<p class="eyebrow">Decision / Next action</p>

# Ask for one clear action

<p class="lede">Name the owner and the review date.</p>

<p class="next"><strong>Next:</strong> State the smallest useful action.</p>

---

<!-- _class: latte appendix -->

# Appendix: evidence and method

- Link the primary source.
- Define the sample.
- Explain the calculation.
- Record the exclusions.
```

## Readability checks

The canvas is 1280 × 720. Main text is 30px, with 72px side margins. Keep content above the footer.

Blue marks rules, large figures and large emphasis. Small labels, sources, links and code use Text or Subtext 1.

Latte Blue on Base is 4.34:1. It does not meet 4.5:1 for ordinary small text. Do not use Blue for small labels.

Panel backgrounds use Mantle, not an arbitrary tint. Check contrast again if a panel colour changes.

Shorten or split content when it does not fit. Do not reduce the whole slide's type size to fit extra text.

Render `specimen.md` after theme changes. Inspect both palettes, code, tables, captions, footers and page numbers before export.
