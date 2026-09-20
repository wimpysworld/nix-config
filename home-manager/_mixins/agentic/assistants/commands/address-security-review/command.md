## Address Security Review

Assess security alerts, delegate bounded fixes, and prepare evidence-based decisions in one pass. This command orchestrates and never implements inline.

Run orchestration only as the coordinator. If a worker loads this body, return a bounded dispatch request with input, scope, authority, and output.
Workers complete assigned assessment, fixes, or verification directly and never launch agents.

### Input and authority

`$ARGUMENTS` supplies alert URLs, a repository with an explicit alert scope, or a local security report.
On Codex, use the accompanying user text as these arguments. If scope is missing or ambiguous, ask before proceeding.
A local finding without a verified GitHub alert identity supports local work only.

Human invocation authorises scoped source fixes, targeted tests, commits, and one push to the selected branch.
It does not authorise alert dismissal, accepted risk, PR approval, thread resolution, merge, release, or force-push.
Carry narrower user restrictions into every worker packet. Preserve unrelated work and existing index contents.

Side effects are scoped source edits, tests, path-limited Git operations, and read-only GitHub access through `gh-api-safe`.
Load `communication-rules`, `gh`, and `delegate-task` before dependent work.
Resolve nested workflows through the available catalogue, configured skill roots, or repository command sources.
Read their bodies before reuse. Never execute generated launch wrappers inside workers.

### Assess before editing

1. Dispatch bounded read-only discovery to Donatello for the selected alerts, repository, branch, and source state.
2. Require all selected alert IDs, URLs, rule/tool identities, scanned refs/SHAs, current source, instances, and prior decisions.
3. Require pagination for alert and instance lists. Stop affected work when access or evidence is incomplete.
4. Give each assessment worker the `draft-security-review` body and exact alert scope, with its read-only restrictions.
5. Route application and dependency verification to Dibble, and infrastructure, CI, or supply-chain verification to Batfink.
6. Require independent per-alert conclusions under that body's assessment rules, including evidence for vendored code and synthetic fixtures.
7. Group proven duplicates for one fix, but retain every alert ID, individual evidence, and proposed action.
8. Leave uncertain alerts open. Do not treat scanner severity, test paths, or vendored paths as proof.

### Fix and validate

1. Group accepted defects by affected paths and dependencies. Sequence overlapping work and parallelise only known independent groups.
2. Dispatch each bounded fix to Donatello with exact paths, accepted evidence, authority, validation, and return requirements.
3. Require reassessment against earlier fixes. Workers must return scope expansion requests before editing additional paths.
4. Workers never stage or commit. Require changed paths, tests, remaining risks, and the alert IDs each fix addresses.
5. Delegate independent security verification to Dibble or Batfink, according to the affected domain.
6. Require verification of the attack path and any claimed mitigation, not merely a passing test.
7. Resolve `make-commit` and `draft-commit-message` and read their workflow bodies in the coordinator context without launch wrappers.
8. If a path contains unrelated changes, stop before staging it. Do not include existing unrelated staged content in a commit.
9. Stage only reported paths with `git add -- <path>`. Never use `git add .`, `-A`, or `-u`.
10. Commit each verified fix from this context only. Supply its paths, intent, evidence, and staged diff to those workflows.
11. Delegate project-appropriate validation after the fixes. Route corrections to Donatello, then verify and commit each correction separately.
12. If validation fails, report the failure and stop before pushing.
13. When changes exist and validation passes, push once with `git push origin <branch>`. Never use a bare push or `-u`.
14. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` with `git rev-parse FETCH_HEAD`.
15. If the SHAs differ, stop. Do not claim that the remote contains the fixes.

### Handover

Dispatch a read-only `draft-security-review` pass with the verified commits, current alerts, and per-alert evidence.
Return its exact proposed actions for review. Use `post-security-review` only after separate authority covers those exact actions and comments.
An implementation is not a dismissal. A push is not scanner-confirmed fixed status.
Report `fixed` only when GitHub confirms that status for the relevant analysis/ref. Otherwise report that scanner confirmation is pending.
Never replace an alert decision with a PR review, a top-level comment, or thread resolution.

### Output

Return the repository/ref and one entry per alert: identity, conclusion, evidence, changed paths, commit, validation, and observed scanner state.
List duplicate links, skipped alerts with reasons, deferred work, pending scanner confirmation, and the exact draft awaiting approval.
Finish with the verified push SHA or `none`, and the next required action. Stop after this pass.
