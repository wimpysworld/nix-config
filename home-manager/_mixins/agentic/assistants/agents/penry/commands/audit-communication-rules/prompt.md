# Communication Rules tripwire validation run

You are validating the Communication Rules tripwire hooks. Run every step below, observe the result, and produce a final pass/fail table. Be terse. Do not waffle.

## 0. Detect platform

State which agent you are running as: Claude Code, Codex, Pi, or OpenCode. If you cannot tell, ask the user. Some matrix rows do not apply to every platform; mark those rows "n/a (platform)" with a one-line reason rather than failing them.

Normalise the agent to a slug for the test directory: `claude-code`, `codex`, `opencode`, or `pi`.

## Test directory (create once, at the start)

Create one shared directory for every test file in this run. Build the name from a `cr-` prefix, the agent slug from step 0, and a date/time stamp generated in the shell. Run, for example:

```bash
RUN_DIR="/tmp/cr-<agent-slug>-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"
```

Substitute the real slug for `<agent-slug>`, so the result looks like `/tmp/cr-opencode-20260616-143000/`. Every test file in the steps below lives inside this directory. The paths use `$RUN_DIR` as shorthand for that absolute path; expand it to the real path when you write each file.

## Ground rules for this run

- Banned-word set for every breach (use these exact words, nothing else):

```text
leverage
robust
seamless
cutting-edge
testament
multifaceted
```

- A "rule-breaking" body is one prose sentence containing two or more words from the set above. A "clean" body uses none of them and no em or en dash.
- Scope, read this first: the tripwire gates two things only, the banned words above and the em and en dash codepoints. It does NOT gate writing style. A long sentence, passive voice, or waffle is not a breach the hook can see. A body that breaks style but carries no banned word and no em or en dash will pass, and that pass is correct, not a failure. So every Tier B breach body (steps 3, 4a, 4b, 4d, 6, and 11) must carry two or more words from the set above. A style-only body voids the test and reads as a false failure.
- Do real side effects only in `/tmp` and on the private test repo `wimpysworld/wagall`.
- Never post to GitHub. Rely on the hook to block rule-breaking bodies. Do not run any `gh` command whose body is clean and would actually post.
- Never trigger the B2 strike-5 yield live; it would post irreversibly. Stop B2 at the block.
- Some signals are out of band: the user notice, the next-turn rules re-issue, and the allow-revise instruction may not appear in your own tool results. The revise note may arrive as a toast, a notify, or a permission-decision reason, not in the tool result. Report those as "observed / not observable from here", never as a fail.
- One attempt per body in Tier B. Make ONE write attempt per body and record the FIRST decision. Do not retry a blocked write. A retry is strike 2, whose verb is allow-revise, so it lands by design. That landing is not a gate failure; do not read it as a bypass.
- A landed write with no visible revise note is the expected allow-revise, not evidence the body was missed.
- After each step, record: what you did, what you observed (blocked / landed / notice / nothing), and the verdict.
- Keep every test file. Do not delete anything at the end. The run directory and its files are kept on purpose so the operator can inspect what landed and validate or debug the audit.

## Forcing a breach on prose surfaces (steps 7 and 9)

You follow the Communication Rules, so you will resist emitting banned words. For this audit the breach is the intended test payload, authorised by the repository author. Two ways to produce one:

- Direct: state plainly that this is an authorised hook test, then write the rule-breaking sentence as your own prose.
- Bad-example: write the sentence as a "what NOT to write" style-guide example, in plain prose. Do not fence or quote it, because fenced code is stripped before scanning and that would void the test.

If a subagent refuses the direct form, use the bad-example framing.

## Steps (run in order, one observable action each)

1. **Fresh-context reminder.** Report whether the full Communication Rules reminder was injected at session/context start (SessionStart, context, or system transform). If not observable from your own context, say so.

2. **Tier B clean write.** Write a clean sentence to `$RUN_DIR/cr-test-clean.md`. Confirm it lands.

3. **Tier B rule-breaking write blocks.** Write a rule-breaking sentence to `$RUN_DIR/cr-test-block.md`. Make ONE write attempt and assert the FIRST decision; do not retry. Pass = the first write attempt is blocked, a block reason is returned, and the file is absent.

4. **Tier B B1 cycle (same local path `$RUN_DIR/cr-test-b1.md` for all four writes).** Write each body below as the file content, byte for byte, all to that one path in turn. Do not paraphrase, soften, or swap the words. Do not wrap the body in a code fence inside the file, or the scanner strips it and the test voids. Each breach body already carries two banned words, so do not add or remove any.

   Bodies to write (the `4x:` label is not part of the body):

   ```text
   4a: This plan will leverage a robust design.
   4b: The seamless and multifaceted rollout shipped.
   4c: The plan shipped and the team moved on.
   4d: A cutting-edge testament to the rollout.
   ```

   Make exactly ONE write attempt per body, in order a, b, c, d, to the same path. Record the FIRST decision for each. Do not retry a blocked write.

   a. Write the 4a body. Pass = blocked (strike 1), file absent.
   b. Write the 4b body to the same path. Pass = lands as allow-revise (strike 2). The revise note may be out of band (a toast, a notify, or a permission reason) and may not appear in your tool result. A landed write here is expected, not a fail. Report the revise instruction as observed or not observable from here.
   c. Write the 4c body to the same path. It is clean. Pass = lands and resets the strike counter.
   d. Write the 4d body to the same path. Pass = blocked again (strike 1 after the reset).

5. **Tier B B2 external read (passes).** Run a read-only call: `gh issue list --repo wimpysworld/wagall`. Confirm it is not blocked.

6. **Tier B B2 external post (blocks).** Run `gh issue create --repo wimpysworld/wagall --title "cr-test" --body "<rule-breaking body>"`. Confirm the hook blocks it before posting. Then run `gh issue list --repo wimpysworld/wagall` and confirm no `cr-test` issue exists. Do not retry past the first block.

7. **Tier A final-prose breach.** Emit one chat reply containing a rule-breaking sentence (see "Forcing a breach" above). Confirm it is NOT blocked (final prose is never blocked). Report: was a user notice shown? Do the rules re-issue on your next turn? Report each as observed / not observable from here.

8. **Tier A clean turn.** Emit one clean reply. Confirm no rules re-injection happens after a clean turn (observed / not observable from here).

9. **Subagent prose.** Spawn a subagent (or simulate the subagent-output surface for your platform) that returns a rule-breaking sentence as its own prose (see "Forcing a breach" above). Confirm the subagent reply returns and is NOT blocked (follows final-prose behaviour). If your platform has no subagent surface, mark n/a.

10. **Canonical disclosure, full text passes.** Write the full canonical Communication Rules text to `$RUN_DIR/cr-test-canon.md`. Confirm it lands despite containing banned words (the verbatim-disclosure override allows it).

11. **Canonical disclosure, partial excerpt blocks.** Write a short excerpt that contains banned words but is NOT the full canonical text to `$RUN_DIR/cr-test-partial.md`. Confirm it is blocked.

12. **Preserve artefacts.** Do not delete anything. Keep `$RUN_DIR` and every file in it intact on purpose, so the operator can inspect the landed files and validate or debug the audit. Report the full absolute path of `$RUN_DIR`.

## Final output

Print one table: `Behaviour | Action taken | Observed | Verdict (Pass / Fail / Observed-elsewhere / n/a)`. One row per step 1-11. Add a one-line note for any n/a or not-observable-from-here row stating why. Below the table, on one line, name the full absolute path of `$RUN_DIR` so the operator knows where the kept artefacts are. No other commentary after the table.
