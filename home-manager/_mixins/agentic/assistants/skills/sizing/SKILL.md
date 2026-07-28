---
name: sizing
description: "Use when sizing or estimating a task, issue, or ticket, or when checking an estimate someone else set. Defines the T-shirt scale (XS, S, M, L, XL) and the shape each size describes, plus the rules for spikes, parent tracking issues, and splitting oversized work. Use even if the user only says 'how big is this', 'what should the estimate be', 'story points', or names a size."
---

# Sizing

One definition of the T-shirt scale. Size on the shape of the work, never on how long it might take.

## The scale

| Size | Points | Shape |
| ---- | ------ | ----- |
| XS | 1 | Trivial and self-evident. A config change, a docs fix, a small bug fix, a single-file edit. No design decision. |
| S | 2 | One focused slice, fully bounded. A standalone bug fix or feature slice with its own tests. Stays inside one module. |
| M | 3 | The workhorse. Clear scope, one owner, several files in one subsystem, with tests and docs. |
| L | 5 | The largest single unit. A new component, or a cross-cutting seam change with a settled design. |
| XL | 8 | Personal projects only. Never on work: split into a parent plus children. |

## Rules

- Index on the shape, never on elapsed time. Do not estimate in days or weeks.
- Unresolved design is not a size, it is a spike. File the spike at XS or S, then size the real work once the design is settled.
- Parent tracking issues carry no estimate. The children carry the size.
- Work stops at L. Personal projects may use XL, but splitting is still the better move.
- Confirm the scale against the live workspace before assigning. The values above are what this workspace uses today, not a fixed truth.

## Telling the workspaces apart

The `WW` team, Wimpy's World, is personal. The `FUL` team, Fulfillment Automation, is work.

## Sprint loading

A human sanity check, not an agent input. A two-week sprint holds 8 XS, or 4 S, or 2 M, or 1 L.
