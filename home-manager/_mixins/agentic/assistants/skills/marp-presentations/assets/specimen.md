---
marp: true
theme: catppuccin-slides
size: 16:9
paginate: true
header: 'Catppuccin slides / Layout specimen'
footer: 'Illustrative content only · Replace all claims and sources'
---

<!-- _class: latte opening -->
<!-- _paginate: false -->

<p class="eyebrow">Latte / Opening</p>

# Make the next decision clear

<p class="lede">A practical system for evidence, technical detail and a clear next action.</p>

<p class="source">Presenter name · Team · Event date</p>

---

<!-- _class: latte agenda -->

# A route to the decision

1. Define the problem
2. Read the evidence
3. Compare the options
4. Agree the next action

---

<!-- _class: latte section -->

<p class="eyebrow">01 / Section</p>

# Start with the evidence

One question. A bounded claim. A source that the audience can check.

---

<!-- _class: latte statement -->

# Reduce the work,<br>not the **confidence**

Use this layout for one claim, not a compressed summary of the whole talk.

---

<!-- _class: latte two-column -->

# Separate the problem from the response

<div class="columns">
<div>

## The problem

Manual checks vary between teams.

- Results are hard to repeat.
- Review time is unpredictable.
- Evidence is easy to lose.

</div>
<div>

## The response

Use one repeatable check before review.

- Keep the result with the change.
- Explain each failed check.
- Leave judgement to the reviewer.

</div>
</div>

---

<!-- _class: latte comparison -->

# Compare the same criteria

| Criterion | Manual review | Repeatable check |
| :--- | :--- | :--- |
| Timing | At each handover | Before handover |
| Evidence | Separate notes | Saved with the change |
| Human role | Repeat routine checks | Review the exceptions |

<p class="source">Example comparison. Validate these claims for the actual workflow.</p>

---

<!-- _class: latte evidence -->

<!--
These figures are **illustrative**, so they do not prove that the change works.
A lower median tells us about the middle result, not every review.
Before we recommend wider use, we need **measured results** from comparable work.
-->

# Review time fell in the pilot

<div class="columns">
<div>

<p class="metric">32%</p>

Less median review time in the example dataset.

</div>
<div>

## A result with limits

The sample includes 40 changes across two teams.

The result does not establish that all teams will see the same reduction.

</div>
</div>

<p class="source">Illustrative data · Baseline: 50 minutes · Pilot: 34 minutes · Not a measured result</p>

---

<!-- _class: latte visual -->
<!-- _paginate: false -->

![bg cover](images/blue-study.svg)

<div class="caption">

# Give the visual room

Keep the conclusion on an opaque caption, not directly over a busy image.

<p class="source">Original sample artwork · Decorative geometry, not data</p>

</div>

---

<!-- _class: latte metrics -->

# Read the values, then the trade-off

| Measure | Baseline | Pilot | Change |
| :--- | ---: | ---: | ---: |
| Median review time | 50 min | 34 min | −32% |
| Changes per sample | 40 | 40 | 0 |
| Checks per change | 6 | 6 | 0 |
| Teams in sample | 2 | 2 | 0 |

<p class="source">Illustrative data, not a measured result. Equal counts do not establish comparable samples.</p>

---

<!-- _class: latte process -->

# Four steps, one review point

1. **Define**<br>Agree the question and the success measure.
2. **Build**<br>Test the smallest useful change.
3. **Measure**<br>Compare the result with the baseline.
4. **Decide**<br>Continue, revise or stop.

<p class="source">Use dates instead of step names for a timeline. Keep each step to two short sentences.</p>

---

<!-- _class: latte code -->

# Keep the check easy to read

```python
from statistics import median

baseline = [48, 50, 52]
pilot = [32, 34, 36]
reduction = 1 - median(pilot) / median(baseline)

print(f"Review time fell by {reduction:.0%}")
```

<p class="source">Python · Illustrative calculation · Keep code to 10 lines and approximately 70 characters per line.</p>

---

<!-- _class: latte architecture -->

# Keep the request path explicit

1. **1. Client**<br>Sends a request with a stable identifier.
2. **2. Service**<br>Validates the request and applies the policy.
3. **3. Store**<br>Saves the result and its audit record.

<p class="boundary">Trust boundary: the service validates all client input before it writes to the store.</p>

<p class="source">Example request flow · Arrows show request direction, not physical network connections.</p>

---

<!-- _class: latte quote -->

<p class="eyebrow">A voice from the review</p>

> “Show me what changed, what you checked and what you need me to decide.”

<p class="source">Example wording, not a sourced quotation · Replace with a named, verified source.</p>

---

<!-- _class: latte closing -->

<p class="eyebrow">Decision / Next action</p>

# Test one bounded change

<p class="lede">Agree the owner, the measure and the review date.</p>

<p class="next"><strong>Next:</strong> Select one team for a two-week pilot.</p>

---

<!-- _class: latte appendix -->

# Appendix: make the evidence traceable

- Link the source and record its date.
- Define the sample and the exclusions.
- Explain the calculation and its units.
- Keep detailed data outside the main narrative.

<p class="source">Appendix is a modifier for the closing family. This slide also checks the standard content layout.</p>

---

<!-- _class: mocha opening -->
<!-- _paginate: false -->

<p class="eyebrow">Mocha / Opening</p>

# Make the next decision clear

<p class="lede">A practical system for evidence, technical detail and a clear next action.</p>

<p class="source">Presenter name · Team · Event date</p>

---

<!-- _class: mocha agenda -->

# A route to the decision

1. Define the problem
2. Read the evidence
3. Compare the options
4. Agree the next action

---

<!-- _class: mocha section -->

<p class="eyebrow">01 / Section</p>

# Start with the evidence

One question. A bounded claim. A source that the audience can check.

---

<!-- _class: mocha statement -->

# Reduce the work,<br>not the **confidence**

Use this layout for one claim, not a compressed summary of the whole talk.

---

<!-- _class: mocha two-column -->

# Separate the problem from the response

<div class="columns">
<div>

## The problem

Manual checks vary between teams.

- Results are hard to repeat.
- Review time is unpredictable.
- Evidence is easy to lose.

</div>
<div>

## The response

Use one repeatable check before review.

- Keep the result with the change.
- Explain each failed check.
- Leave judgement to the reviewer.

</div>
</div>

---

<!-- _class: mocha comparison -->

# Compare the same criteria

| Criterion | Manual review | Repeatable check |
| :--- | :--- | :--- |
| Timing | At each handover | Before handover |
| Evidence | Separate notes | Saved with the change |
| Human role | Repeat routine checks | Review the exceptions |

<p class="source">Example comparison. Validate these claims for the actual workflow.</p>

---

<!-- _class: mocha evidence -->

# Review time fell in the pilot

<div class="columns">
<div>

<p class="metric">32%</p>

Less median review time in the example dataset.

</div>
<div>

## A result with limits

The sample includes 40 changes across two teams.

The result does not establish that all teams will see the same reduction.

</div>
</div>

<p class="source">Illustrative data · Baseline: 50 minutes · Pilot: 34 minutes · Not a measured result</p>

---

<!-- _class: mocha visual -->
<!-- _paginate: false -->

![bg cover](images/blue-study.svg)

<div class="caption">

# Give the visual room

Keep the conclusion on an opaque caption, not directly over a busy image.

<p class="source">Original sample artwork · Decorative geometry, not data</p>

</div>

---

<!-- _class: mocha metrics -->

# Read the values, then the trade-off

| Measure | Baseline | Pilot | Change |
| :--- | ---: | ---: | ---: |
| Median review time | 50 min | 34 min | −32% |
| Changes per sample | 40 | 40 | 0 |
| Checks per change | 6 | 6 | 0 |
| Teams in sample | 2 | 2 | 0 |

<p class="source">Illustrative data, not a measured result. Equal counts do not establish comparable samples.</p>

---

<!-- _class: mocha process -->

# Four steps, one review point

1. **Define**<br>Agree the question and the success measure.
2. **Build**<br>Test the smallest useful change.
3. **Measure**<br>Compare the result with the baseline.
4. **Decide**<br>Continue, revise or stop.

<p class="source">Use dates instead of step names for a timeline. Keep each step to two short sentences.</p>

---

<!-- _class: mocha code -->

# Keep the check easy to read

```python
from statistics import median

baseline = [48, 50, 52]
pilot = [32, 34, 36]
reduction = 1 - median(pilot) / median(baseline)

print(f"Review time fell by {reduction:.0%}")
```

<p class="source">Python · Illustrative calculation · Keep code to 10 lines and approximately 70 characters per line.</p>

---

<!-- _class: mocha architecture -->

# Keep the request path explicit

1. **1. Client**<br>Sends a request with a stable identifier.
2. **2. Service**<br>Validates the request and applies the policy.
3. **3. Store**<br>Saves the result and its audit record.

<p class="boundary">Trust boundary: the service validates all client input before it writes to the store.</p>

<p class="source">Example request flow · Arrows show request direction, not physical network connections.</p>

---

<!-- _class: mocha quote -->

<p class="eyebrow">A voice from the review</p>

> “Show me what changed, what you checked and what you need me to decide.”

<p class="source">Example wording, not a sourced quotation · Replace with a named, verified source.</p>

---

<!-- _class: mocha closing -->

<p class="eyebrow">Decision / Next action</p>

# Test one bounded change

<p class="lede">Agree the owner, the measure and the review date.</p>

<p class="next"><strong>Next:</strong> Select one team for a two-week pilot.</p>

---

<!-- _class: mocha appendix -->

# Appendix: make the evidence traceable

- Link the source and record its date.
- Define the sample and the exclusions.
- Explain the calculation and its units.
- Keep detailed data outside the main narrative.

<p class="source">Appendix is a modifier for the closing family. This slide also checks the standard content layout.</p>
