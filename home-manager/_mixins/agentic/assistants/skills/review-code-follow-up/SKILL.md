---
name: review-code-follow-up
description: "Use for a follow-up code review after an author responds to earlier findings, including requests to re-review, review again, verify fixes, or check addressed feedback. Rechecks the prior feedback and the response delta without restarting the full review."
user-invocable: true
---

# Review Code Follow-up

Verify the author's response to a completed review. Keep GitHub access read-only and keep the report private.

## Resolve the target and prior report

1. Apply `communication-rules`, `contribution-voice`, and `review-report-path`. Read each first unless its complete, current instructions are already in this context.
2. Resolve the input as an exact final report path, a `run-*` ID, or a review target. Blank means the current worktree.
3. For an exact path, derive the project from the current repository. Resolve the report root and file parent with POSIX `cd -P` and `pwd -P`, without `realpath` or `readlink -f`. Accept only a regular, non-symbolic-link file under `<physical-report-root>/<project>/<target>/run-*/`, with single directory components for `<target>` and `run-*`. Reject paths outside that tree and `findings-*.md`.
4. For a target, derive the exact project and target directory with `review-report-path`. If the target can resolve to more than one pull request, branch, worktree, or commit, list the choices and ask the user to select one.
5. Exclude fallback files. Sort final reports by the UTC timestamp in each `run-*` directory and use the sole report in the latest timestamped run. If a timestamp is missing or malformed, that run has several final reports, timestamps tie across runs, or more than one target remains plausible, list the exact paths and ask the user to select one. This latest-report rule is specific to follow-up reviews and overrides the general selection rule in `review-report-path`.
6. If the selected source is a follow-up report, keep it as the direct source. Follow its `Source report` chain only to validate the chain and recover the original review contract. Reject a missing, unsafe, or cyclic source path.
7. If no prior report exists, list the available target directories and stop. Tell the user to run an initial `review-code-*` command first. Never substitute a fresh full review.

Treat an explicit report path or run ID as the user's selection. Never delete or overwrite a report.

## Recover the review contract

Read the direct source report and recover:

- every actionable finding from its `Findings` section, including its severity and proof
- its reviewed head SHA
- the lens and severity bar from the original report in the source chain
- the original target

For an initial source report, use its `Reviewed SHA`. For a follow-up source report, use its `Current reviewed SHA`. This SHA is the response-delta baseline.

Use the recorded contract. When an older report has no contract fields, derive the target from its report path and derive the lens only from the original report name (`code-review-colleague`, `code-review-community`, or `code-review-mine`) and its matching command. Recover a reviewed SHA from an unambiguous full or abbreviated commit in the report when Git can resolve it. If the lens or target still cannot be identified without guessing, stop and ask.

Preserve the original lens and severity bar. Do not widen either one, and do not run the wide fan-out or topic sweep from `review-code`.

If the direct source has no actionable finding, stop. Tell the user to run an initial `review-code-*` command for code changed after a clean review.

## Recheck the prior findings

Reproduce each finding from the direct source against the current target and assign exactly one status:

| Status | Meaning |
| --- | --- |
| `resolved` | The defect and its prior failure mode no longer apply. |
| `partly resolved` | The response reduces the defect, but a stated precondition or outcome still fails. |
| `unresolved` | The defect still applies. |
| `withdrawn` | New evidence proves that the prior finding was incorrect or inapplicable, rather than fixed. |

Use code, tests, builds, or runtime evidence where practical. Do not mark a finding resolved only because the relevant lines changed. Record concise proof for every status.

## Review the response delta

Resolve the current target head and inspect the delta from the source report's reviewed SHA to that head. Review changed lines and directly affected callers or tests only for defects caused by the author's response.

If the source SHA is absent locally, use a clearly read-only GitHub comparison when the target is a pull request. If the SHA still cannot be obtained, recheck the prior findings against the current target, mark the response-delta check as unavailable, and do not attribute a new defect to the response.

A response-caused defect must pass the original lens and severity bar. Suppress unrelated findings that the prior review missed unless the evidence shows a serious security, data-loss, outage, or production-correctness risk. A serious defect can compromise protected data, destroy durable data, stop a production service, or produce materially wrong production results under realistic conditions. Adversarially verify the preconditions and deployment impact of each permitted serious missed defect before reporting it.

Do not restart the full review, inspect unchanged areas for general defects, add preference-level feedback, or create a new round of optional suggestions.

## Write the report

Create a new exclusive run directory for the same target with `review-report-path`. Write `code-review-again.md` there with this structure:

```markdown
# Follow-up Code Review

Source report: <exact direct source path>
Original report: <exact root report path>
Previous reviewed SHA: <sha or unavailable>
Current reviewed SHA: <sha>
Target: <resolved target>
Lens: <original lens>
Severity bar: <original bar>

## Summary

<scope and conclusion>

## Verification

<checks and response-delta range, or the exact limitation>

## Prior Findings

1. **<status>**: <prior finding identifier and concise proof>

## Findings

<only actionable current findings, or "None.">

## Conclusion

<what remains and whether another author response is required>
```

Put each `partly resolved` or `unresolved` prior defect in `Findings`. Also put response-caused defects and permitted serious missed defects there. Keep resolved and withdrawn items only in `Prior Findings`, so `draft-code-review` continues to read `Findings` only.

Apply `contribution-voice` when wording every actionable finding. Each finding is at most three sentences: the defect, the proof with one `file:line`, and the fix. Do not draft or post a GitHub comment, state a review verdict, or mutate GitHub.

Return the conclusion, each finding that needs action, and the report path.
