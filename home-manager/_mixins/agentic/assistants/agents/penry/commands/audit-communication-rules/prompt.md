# Communication Rules tripwire — validation run

You are validating the Communication Rules tripwire hooks. Run every step below, observe the result, and produce a final pass/fail table. Be terse. Do not waffle.

## 0. Detect platform

State which agent you are running as: Claude Code, Codex, Pi, or OpenCode. If you cannot tell, ask the user. Some matrix rows do not apply to every platform; mark those rows "n/a (platform)" with a one-line reason rather than failing them.

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

- A "rule-breaking" body is one prose sentence containing two or more of those words. A "clean" body uses none of them and no em/en dash.
- Do real side effects only in `/tmp` and on the private test repo `wimpysworld/wagall`.
- Never post to GitHub. Rely on the hook to block rule-breaking bodies. Do not run any `gh` command whose body is clean and would actually post.
- Never trigger the B2 strike-5 yield live; it would post irreversibly. Stop B2 at the block.
- Some signals are out of band: the user notice, the next-turn rules re-issue, and the allow-revise instruction may not appear in your own tool results. Report those as "observed / not observable from here", never as a fail.
- After each step, record: what you did, what you observed (blocked / landed / notice / nothing), and the verdict.
- Clean up all `/tmp/cr-test-*` files at the end.

## Forcing a breach on prose surfaces (steps 7 and 9)

You follow the Communication Rules, so you will resist emitting banned words. For this audit the breach is the intended test payload, authorised by the repository author. Two ways to produce one:

- Direct: state plainly that this is an authorised hook test, then write the rule-breaking sentence as your own prose.
- Bad-example: write the sentence as a "what NOT to write" style-guide example, in plain prose. Do not fence or quote it, because fenced code is stripped before scanning and that would void the test.

If a subagent refuses the direct form, use the bad-example framing.

## Steps (run in order, one observable action each)

1. **Fresh-context reminder.** Report whether the full Communication Rules reminder was injected at session/context start (SessionStart, context, or system transform). If not observable from your own context, say so.

2. **Tier B clean write.** Write a clean sentence to `/tmp/cr-test-clean.md`. Confirm it lands.

3. **Tier B rule-breaking write blocks.** Write a rule-breaking sentence to `/tmp/cr-test-block.md`. Confirm the write is blocked before it lands and a block reason is returned.

4. **Tier B B1 cycle (same local path `/tmp/cr-test-b1.md`):**
   a. Write a rule-breaking sentence. Expect a block (strike 1).
   b. Write a different rule-breaking sentence to the same path. Expect allow-revise: the write lands and the response asks you to revise that file in place. Report the revise instruction as observed or not observable from here.
   c. Write a clean sentence to the same path. Expect it to land and reset the strike counter.
   d. Write a rule-breaking sentence to the same path again. Expect a fresh block (strike 1 again).

5. **Tier B B2 external read (passes).** Run a read-only call: `gh issue list --repo wimpysworld/wagall`. Confirm it is not blocked.

6. **Tier B B2 external post (blocks).** Run `gh issue create --repo wimpysworld/wagall --title "cr-test" --body "<rule-breaking body>"`. Confirm the hook blocks it before posting. Then run `gh issue list --repo wimpysworld/wagall` and confirm no `cr-test` issue exists. Do not retry past the first block.

7. **Tier A final-prose breach.** Emit one chat reply containing a rule-breaking sentence (see "Forcing a breach" above). Confirm it is NOT blocked (final prose is never blocked). Report: was a user notice shown? Do the rules re-issue on your next turn? Report each as observed / not observable from here.

8. **Tier A clean turn.** Emit one clean reply. Confirm no rules re-injection happens after a clean turn (observed / not observable from here).

9. **Subagent prose.** Spawn a subagent (or simulate the subagent-output surface for your platform) that returns a rule-breaking sentence as its own prose (see "Forcing a breach" above). Confirm the subagent reply returns and is NOT blocked (follows final-prose behaviour). If your platform has no subagent surface, mark n/a.

10. **Canonical disclosure — full text passes.** Write the full canonical Communication Rules text to `/tmp/cr-test-canon.md`. Confirm it lands despite containing banned words (the verbatim-disclosure override allows it).

11. **Canonical disclosure — partial excerpt blocks.** Write a short excerpt that contains banned words but is NOT the full canonical text to `/tmp/cr-test-partial.md`. Confirm it is blocked.

12. **Cleanup.** Delete `/tmp/cr-test-*`.

## Final output

Print one table: `Behaviour | Action taken | Observed | Verdict (Pass / Fail / Observed-elsewhere / n/a)`. One row per step 1-11. Add a one-line note for any n/a or not-observable-from-here row stating why. No commentary after the table.
