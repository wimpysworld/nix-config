## Validate Plan

Validate an implementation against its proposal and implementation plan.

Input references: $ARGUMENTS. Use them if they include the proposal, plan, and implementation diff or changed files. Ask for any missing input before reviewing.

### Workflow

1. Read the proposal, plan, and implementation diff or changed files before judging.
2. Compare the implementation against both the plan and the proposal. Treat the proposal as intent and the plan as the task contract.
3. Delegate to a wide fan-out of sub-agents, in parallel where possible.
4. Spread review of a complete implementation wide so each sub-agent task stays small and well bounded. Split by plan task, subsystem, risk area, changed-file cluster, or test surface.
5. Use Penry for code quality review and Brain for test evidence when useful. Use Penfold only if proposal intent is ambiguous.
6. Aggregate the findings into a pass/fail judgement with required fixes. Do not rewrite the plan.
7. If gaps are found, delegate to Donatello to resolve them. Apply the same wide sub-agent rule for that fix pass.

### Review Focus

- Missing work from the plan or proposal.
- Extra work outside the plan or proposal.
- Behavioural drift from requested intent.
- Unresolved risks, flags, or plan questions.
- Unclear items that block a sound judgement.
- Test evidence that is absent, weak, or mismatched to the change.
- Code quality issues that affect correctness, maintenance, or fit with existing patterns.

### Output

```markdown
## Judgement

Pass / Fail - one sentence explaining why.

## Required Fixes

| Priority | Finding | Evidence | Required fix |
| -------- | ------- | -------- | ------------ |
| P0/P1/P2 | Missing, extra, drift, risk, unclear, test, or quality issue | Proposal, plan, diff, file path, or sub-agent result | Concrete fix required before pass |

## Checks

| Area | Result | Evidence |
| ---- | ------ | -------- |
| Proposal alignment | Pass / Fail | Notes |
| Plan coverage | Pass / Fail | Notes |
| Implementation scope | Pass / Fail | Notes |
| Risks and unclear items | Pass / Fail | Notes |
| Tests | Pass / Fail | Notes |
| Code quality | Pass / Fail | Notes |

## Delegation

| Agent | Scope | Result |
| ----- | ----- | ------ |
| Agent name | Bounded review or fix scope | Key result |
```

Omit empty rows, but keep the section headings. If the result is pass, state "No required fixes." under Required Fixes.
