## Review Proposal

Review the proposal referenced by $ARGUMENTS.

If $ARGUMENTS is blank, ask for the proposal path or text before reviewing.

### Purpose

Assess whether the proposal is clear, evidenced, scoped, and ready to become a mechanical implementation plan.

### Process

1. Read the full proposal before judging.
2. Check material claims against the codebase, source documents, current docs, or web sources where needed.
3. Identify gaps in clarity, evidence, assumptions, options, risks, scope, success criteria, and trade-offs.
4. Decide whether Donatello can turn the proposal into a plan without guessing.
5. Keep task sequencing, implementation validation, code quality review, and diff review out of scope.

### Review Focus

| Area | Question |
| ---- | -------- |
| Clarity | Is the objective, user value, and intended behaviour clear? |
| Evidence | Are important claims backed by code, docs, research, or explicit reasoning? |
| Assumptions | Are hidden assumptions named, tested, or marked as open questions? |
| Options | Are credible alternatives considered, with reasons for the chosen path? |
| Risks | Are technical, product, data, security, migration, and dependency risks covered? |
| Scope | Are in-scope and out-of-scope boundaries clear enough to prevent drift? |
| Success Criteria | Are acceptance criteria testable and linked to the objective? |
| Trade-offs | Are costs, constraints, reversibility, and follow-on effects stated? |
| Plan Readiness | Can the proposal become a plan without new product or architecture decisions? |

### Output

```markdown
## Verdict

Ready / Ready with caveats / Needs revision - one sentence explaining why.

## Findings

| Priority | Area | Finding | Evidence | Recommendation |
| -------- | ---- | ------- | -------- | -------------- |
| P0/P1/P2 | Clarity, evidence, assumptions, options, risks, scope, success criteria, trade-offs, or readiness | Genuine gap | Proposal line, code path, document, or source citation | One clear action |

## Readiness To Plan

State what Donatello can plan now, what must change first, and what questions remain.
```

Omit empty table rows. If there are no findings, state "No proposal issues found" under Findings.

### Constraints

- Review proposal quality, not plan mechanics.
- Do not assess task order, task size, dependency chains, test commands, or implementation fit.
- Do not compare an implementation diff against the proposal.
- Route intent drift between a proposal and an existing plan to the alignment flow.
- Route execution fit and completed implementation checks to Donatello's `validate-plan`.
- Do not invent findings. Every finding must cite proposal text, repository evidence, source documents, or current research.
