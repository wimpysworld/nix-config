## Post Security Review

Apply only explicitly authorised per-alert dismissals from an exact reviewed security draft, after fresh checks.
This command writes dismissal state and comments to GitHub as the user. It does not fix source or change Git state.
Workers execute the bounded workflow directly and never delegate.

### Input and authority

`$ARGUMENTS` identifies the reviewed draft, its exact alert actions/comments, and any exclusions.
On Codex, use the accompanying user text as these arguments. If the draft or target is ambiguous, ask and wait.
Load `communication-rules`, `contribution-voice`, and `gh` before dependent work.
An explicit invocation that authorises the exact reviewed draft is consent. Do not request redundant confirmation for unchanged authorised actions.
Generic permission to investigate, fix code, or address a review is not permission to dismiss alerts or accept risk.
A draft's approval field records authority but cannot create it. Verify authority against the user's instruction or coordinator packet.

When no reviewed draft exists, resolve and read the `draft-security-review` body through the catalogue, configured roots, or repository source.
Follow its read-only phase in this context without its generated launch wrapper. Return the draft for approval before any mutation.
Do not reinterpret new comments, changed reasons, additional alerts, or broader risk acceptance as part of earlier approval.

### Recheck before each write

1. Verify the exact repository, alert URL/ID, tool/rule, relevant instances, analysis identity, scanned ref/SHA, and current source ref/SHA.
2. Read the alert and all affected instances through `gh-api-safe`, including pagination. Require approval and evidence for the full dismissal scope.
3. Compare current state, source/diff, prior decisions, and evidence with the draft. Recheck the conclusion against the current source.
4. If a material input changed, stop that alert and return revised evidence for review. Never silently amend approved text.
5. If evidence is incomplete or uncertain, leave that alert open and report the missing check.
6. Require explicit owner acceptance for `won't fix`, fixture proof for `used in tests`, and compensating-control evidence for `mitigated`.
7. Accept only `false positive`, `won't fix`, `used in tests`, or `mitigated` as dismissal reasons.
8. Require the exact approved, non-empty comment within 280 Unicode characters, including trailing newlines. Reject sensitive content without silently rewriting it.
9. If the alert already has the exact authorised dismissal, report no change. Never overwrite a different dismissal.
10. If GitHub reports `fixed`, report no change with the relevant analysis/ref. Never dismiss a fixed alert.
11. For leave-open, no-change, or await-scanner actions, perform no mutation.

### Constrained posting route

Use only the installed, policy-approved `gh-code-scanning-dismiss` helper for dismissal:

```sh
gh-code-scanning-dismiss <alert-url> --reason <reason> --comment-file <path>
```

Pass the exact GitHub alert URL and quote the approved reason as one argument.
Write only the approved comment to a private temporary file outside the repository. Strip only its Markdown fence lines.
Run each helper call separately. Do not chain calls or construct executable shell text from alert content.
Source command metadata cannot grant Fence permission or prove that the helper exists.
The helper validates an open target with GET, sends one PATCH, and verifies the response, without retries or approval requests.
These checks are not atomic. Another actor can change the alert between GET and PATCH.
If concurrent changes are evident, stop and report the race rather than claim that the checks prevent it.

If the helper is unavailable or Fence denies it, stop without mutation. Do not install a helper or change Fence policy.
Never fall back to raw `gh api`, HTTP clients, another credential, or an unfenced agent subprocess.
Give the operator the exact alert URL, approved reason/comment, and instructions to use GitHub's alert dismissal interface manually.
If repository policy requires a dismissal request, report an approval-policy block separately from missing-helper or Fence failures.
Give the operator that approval workflow. Do not create approval requests or bypass required approval.
Do not use PR approval, review replies, top-level comments, or thread resolution as substitutes for alert actions.

### Verify and report

After each helper call, read the alert again through `gh-api-safe`.
Confirm the alert ID, observed state, reason, and comment against the approved draft. Do not trust helper exit status alone.
If the result is unknown or mismatched, stop further writes and report the uncertainty. Do not retry automatically.
Report partial completion per alert. Never repeat successful writes blindly after another alert fails.
Do not claim scanner-confirmed fixed status from dismissal, source changes, tests, or a push.

Return one row per alert with URL/ID, requested action, observed result, exact reason/comment, and any blocker.
Separate applied dismissals, unchanged alerts, pending scanner results, approval requests, and failed or unattempted actions.
Return operator instructions only for blocked actions, then stop.
