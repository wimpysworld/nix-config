# Communication Rules tripwire

Shared scanner, adapters, and fixtures that enforce the Communication Rules across Claude Code, Codex, Pi, and OpenCode. Nix generates the rules fragment, scanner, and policy once; each agent wires its own adapter.

## Layout

- `scanner.py` deterministic checker for banned words, dashes, and policy disclosure.
- `adapters/` per-agent extraction and gating shims over the shared `contract.sh`.
- `fragment.nix` generates the rules text, reminder, block, and correction prompts.
- `fixtures/` and `tests/` per-agent expected-behaviour cases.

## Why this exists

The Communication Rules keep agent output short, plain, and easy to read. That serves two goals.

First, clarity and productivity. A reader gets the answer in fewer words. A non-native English speaker understands it on the first read.

Second, the rules are a policy in the token-optimised agent loop. The loop is described in the assistants instructions README at `../../assistants/instructions/README.md`. Parent context is permanent and finite, so every wasted word costs the loop. Terse, on-rule output is part of that economy, not a style preference.

## Design principles

Two principles shape every part of this gate.

**The sensor is deterministic and independent of the model.** Detection cannot ask another LLM to judge, because LLM output is probabilistic. The gate is a stdlib-only Python scanner doing exact, mechanically testable checks: the em and en dash characters, and an exact-match subset of the banned words. The thing that controls the model must not be the model. That keeps the gate testable with fixtures and stops a bad model from talking its way past its own checker.

**One source of truth feeds the model and the gate.** Nix generates a single Communication Rules fragment. The same fragment feeds global instructions, every generated subagent prompt, session reminders, and the hook re-issue text. So what the model is told and what the gate enforces cannot drift apart.

**Each agent uses its own best native mechanism.** The design does not force one shared hook model across the four agents. Each adapter wires the gate through the hook or extension that fits its platform, which is why the output contracts differ per agent (see the table below).

## The core constraint

No agent can block streamed prose before the user sees it. By the time a hook fires on a final message, the words are already on screen.

So enforcement is best-effort. It is tuned to keep the model aligned over time, not to perfect a single message. We accept that the odd breach is surfaced, and we correct the next reply.

## The two tiers

Enforcement scales to blast radius. The hook surface decides the tier.

### Tier B: world-visible output

This covers writes, edits, patches, Bash command bodies, and post bodies (gh and MCP). These are intercepted before they run, so a breach can still be stopped.

The policy is strike-then-yield, split by blast radius into two sub-tiers:

- **B1 (local): writes, edits, patches, and Bash command bodies.** Cheap to retract because they land on disk, not committed. Three strikes, keyed per tool-call content. Strikes 1 and 2 block and re-issue the rules; strike 3 yields with a short notice.
- **B2 (external): gh, gh-api-safe, MCP posts, and gh posts run through Bash.** Irretractable the instant they yield. Five strikes, keyed on a stable identity (session and tool, no body) so reworded retries of the same post draw down one budget. Strikes 1 to 4 block and re-issue; strike 5 yields with an operator-visible notice that names the tool and target (`Rules breach posted: <target>`).

We retry, then yield. Blocking automation forever is friction users will not accept. The local path tries twice; the external path tries four times before the irreversible yield. The cost is that imperfect output is sometimes surfaced after the retries.

A Bash call is external when its first token is `gh` or `gh-api-safe` and it carries a post signal (a body-bearing flag or a POST/PATCH/PUT method); read-only gh calls stay local.

### Tier A: user-facing and agent-facing prose

This covers the final assistant message and subagent or agent-to-agent prose. These cannot be blocked before the reader sees them, so they are never blocked and never re-rolled.

On a flagged final message:

- The model gets a silent re-issue of the rules so it self-corrects on the next turn. The user does not see this.
- The user sees a short notice that a breach was seen and acted on.

There is no strike loop here. We never block, so each offending turn gets one re-issue plus one notice. We tolerate the odd miss.

## What is inspected

The gate scans only prose the agent emits as its own outgoing words:

- File writes.
- Edits and patch additions.
- External post bodies (gh, gh-api-safe, post-capable MCP).
- Agent-to-agent and subagent prose.
- Final replies.

Fenced code blocks are stripped before scanning, so code is never flagged. Quoted dashes or banned words that remain in prose are blocked by design; if the agent writes them as its own text, it owns them.

The gate does not scan:

- Incoming tool output. It may quote external text the agent does not own, so blocking on it would punish the agent for words it did not write.
- Arbitrary Bash arguments.
- Binary content.
- Build logs.
- External text the agent is reading, not posting as its own.

Bash scanning stays narrow on purpose. It covers obvious prose side effects and recognised gh or gh-api-safe post bodies, not a full shell parse. A Bash post body whose outgoing text cannot be read fails closed, the same as any other uninspectable write, edit, or post.

## Per-agent mechanism

Each platform has its own hook contract. The table shows how each tier is delivered, so the parity and the platform limits are visible. Every Tier B adapter uses the same split: three strikes for B1 local (write, edit, patch, Bash), five strikes for B2 external (gh, gh-api-safe, MCP posts, gh posts run through Bash). The local path keys per tool-call content; the external path keys on a stable session-and-tool identity and yields with an operator notice naming the target.

| Agent       | Tier B world output (PreToolUse)                                              | Tier A facing prose                                                                                  |
| ----------- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Claude Code | B1: `permissionDecision` deny (re-issue) x2, then allow (notice), keyed per session, tool, and content. B2: deny x4, then allow with a target-naming notice, keyed per session and tool. Strike state in a runtime dir. | Stop emits a lone `systemMessage` notice and sets a pending flag; the next `UserPromptSubmit` injects the re-issue as `additionalContext`. |
| Codex       | B1: `permissionDecision` deny x2, then allow, keyed per session, turn, tool, and body. B2: deny x4, then allow with a target-naming notice, keyed per session, turn, and tool. Strike state reuses the strike dir. | Stop emits a `systemMessage` notice and sets a pending flag; the next `UserPromptSubmit` injects the re-issue as `additionalContext`. |
| OpenCode    | B1: `tool.execute.before` throws to block x2, then yields and toasts, keyed per session, tool, and body hash. B2: throws x4, then yields with a target-naming toast, keyed per session and tool. Strike state is an in-process map. | A flagged final sets a pending flag and toasts; `experimental.chat.system.transform` appends the re-issue while the flag is set, then clears it. |
| Pi          | B1: `tool_call` returns a block x2, then yields and notifies, keyed per session, tool, and input hash. B2: blocks x4, then yields with a target-naming notice, keyed per session and tool. Strike state is a closure map. | A flagged final sets a pending flag and notifies; the `context` hook appends a `display:false` re-issue message while the flag is set, then clears it. |

Claude Code and Codex have no silent per-turn channel on Stop, so the re-issue lands on the next `UserPromptSubmit`. OpenCode and Pi have a true silent channel, so the re-issue lands on the next context build of the same turn loop.

## Fail-closed and disclosure

Tier B stays fail-closed: if extraction fails on a world-output surface, the call is denied under the same strike cap rather than letting unscanned prose through. A write, edit, or post whose outgoing prose cannot be read is treated as a breach, not waved through.

There is no agent bypass. No flag, env var, allow rule, or prompt escape lets an agent skip the gate. The operator can still recover from a false positive: disable hooks through the operator-owned mechanism, or rebuild without this mixin. That recovery sits outside the inspected agent action, so it is operator control, not an agent bypass.

The re-issue hides the trigger. It asks for full Communication Rules compliance and never names the specific dash or word that fired. If the model learned which single trigger it tripped, it could treat that as a cheat code, avoid that one thing, and ignore the rest of the rules.

The scanner allows the rules themselves through, so a request to view or quote the Communication Rules is not flagged as a breach.
