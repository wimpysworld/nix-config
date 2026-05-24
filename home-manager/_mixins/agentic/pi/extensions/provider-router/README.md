# Provider Router

Provider Router is a local Pi extension for subagent model routing. It
intercepts Pi `tool_call` events for the `subagent` tool. When the requested
subagent has a model and/or thinking-level mapping for the active provider, it
writes `params.model` in Pi's canonical `provider/id[:thinking]` form. For known
agents the routing is authoritative: the per-agent mapping always wins, even if
the orchestrator passed an explicit `model` on the tool call. Pi then hands the
call to `pi-subagents`.

## Deployed Scope

Home Manager deploys the extension under
`~/.pi/agent/extensions/provider-router/`. The directory contains
`agents.json`, `thinking.json`, `index.ts`, `LICENSE`, and `README.md`.

`index.ts` is the runtime extension. `agents.json` and `thinking.json` are both
generated from assistant `header.pi.yaml` files. The runtime reads them from
`~/.pi/agent/extensions/provider-router/`.

## Map Format

`agents.json` is an object keyed by agent name. Each agent value is an object
keyed by provider name. Each provider value is the model id for that provider.

```json
{
  "garfield": {
    "anthropic": "claude-haiku-4-5",
    "google": "gemini-3-flash",
    "openai-codex": "gpt-5.4-mini"
  }
}
```

For an Anthropic parent session, the runtime writes
`anthropic/claude-haiku-4-5`. For an `openai-codex` parent session, it writes
`openai-codex/gpt-5.4-mini`.

`thinking.json` mirrors that shape with one value per provider drawn from
Pi's closed set of effort levels (`off`, `minimal`, `low`, `medium`, `high`,
`xhigh`):

```json
{
  "donatello": { "openai-codex": "xhigh" },
  "penfold":   { "openai-codex": "high" },
  "garfield":  { "openai-codex": "medium" }
}
```

When both a model and a thinking level are mapped, the runtime emits
`provider/modelId:thinking`. When only a thinking level is mapped, it reuses
the active session model id (`ctx.model.id`) as the bare model and emits
`provider/<active-id>:thinking`. The unsuffixed model id is the only value
passed to `ctx.modelRegistry.find`; the thinking suffix is Pi routing syntax
and must not reach the registry lookup.

## Declaration Format

Declare provider-specific models and effort in an agent's `header.pi.yaml`. The
suffix after `model-` or `thinking-` must match the active Pi provider name
exactly, including hyphens (`openai-codex`, not `openai`):

```yaml
model-anthropic: claude-haiku-4-5
model-openai-codex: gpt-5.4-mini
model-google: 'gemini-3-flash'
thinking-openai-codex: xhigh
```

The provider name is the suffix after `model-` or `thinking-`. The harvester
accepts plain scalar values, plus matching single or double quotes which it
strips. It ignores empty values, block scalars, anchors, aliases, unmatched
quotes, and unquoted values containing `:`. `thinking-<provider>` values are
validated at evaluation time against the closed set
`off|minimal|low|medium|high|xhigh`; invalid values fail `nix eval` with a
clear message. Provider names are not validated; a typo simply becomes a map
key that never matches the active Pi provider.

This repo declares both `model-<provider>` and `thinking-<provider>`
explicitly for every named agent, so the routing decision is readable from
the agent's own `header.pi.yaml` rather than inferred from Pi's
`defaultModel` and `defaultThinkingLevel`. The runtime still accepts
thinking-only entries (it falls back to `ctx.model.id` for the bare model in
that case), and bare `model-<provider>` entries without a thinking sibling
still produce `provider/modelId` without a thinking suffix. Explicit
`model-<provider>` plus `thinking-<provider>` is the preferred form.

## Runtime Constraints

Provider Router covers the LLM tool-call path only. It rewrites `subagent`
calls produced by the model during a Pi session. It does not cover slash
commands such as `/run`, `/chain`, `/parallel`, or `/run-chain`. It does not
cover prompt-template-bridge invocations. v1 has no per-project override.

For known agents - those with a `model-<provider>` and/or
`thinking-<provider>` entry for the active provider - the runtime is
authoritative. It rewrites `params.model` whether or not the orchestrator
supplied one, and applies the thinking suffix consistently. Unknown agents
(no entry for the active provider in either map) pass through untouched. The
runtime validates the bare model via `ctx.modelRegistry.find(provider, modelId)`
before writing anything; only models available to the authenticated Pi session
are used. The suffixed string is never passed to the registry.

When the extension overrides a value the orchestrator passed (i.e. `task.model`
was set and differs from the routed value), it emits a single line to stderr:

```
provider-router: override model for agent=<name> orchestrator=<orig> -> routed=<new>
```

No log is emitted in the common case where the orchestrator left `model` unset.

## Graceful No-Ops

These miss paths leave `params.model` unchanged:

1. The agent is absent from both `agents.json` and `thinking.json`.
2. The agent has no entry for the active provider in either map.
3. The mapped (or active-session) model is not authenticated locally.
4. There is no active provider, or no active session model when only a
   thinking level is mapped.

In all cases, `pi-subagents` receives the original call. Its resolver then
falls through to `agentConfig.model` from frontmatter. If that is absent, it
inherits the parent model.

If either sidecar file cannot be read or parsed, the extension uses an empty
map for that source. Every lookup against that source then follows the first
miss path.

## Freshness

The extension loads the map at startup. It refreshes the map on Pi
`session_start` and `resources_discover` events. Long-running sessions may not
see an out-of-band `home-manager switch`. Run `/reload` or restart the Pi
session after changing `agents.json`.

## Verification

Check that Home Manager's evaluated bytes match the deployed maps:

```sh
nix eval --raw .#homeConfigurations.\"martin@skrye\".config.home.file.\".pi/agent/extensions/provider-router/agents.json\".text > /tmp/router-eval.json
diff /tmp/router-eval.json ~/.pi/agent/extensions/provider-router/agents.json
nix eval --raw .#homeConfigurations.\"martin@skrye\".config.home.file.\".pi/agent/extensions/provider-router/thinking.json\".text > /tmp/router-thinking-eval.json
diff /tmp/router-thinking-eval.json ~/.pi/agent/extensions/provider-router/thinking.json
```

Check deployed files and smoke-test Pi extension loading:

```sh
test -f ~/.pi/agent/extensions/provider-router/agents.json
test -f ~/.pi/agent/extensions/provider-router/thinking.json
test -f ~/.pi/agent/extensions/provider-router/index.ts
test -f ~/.pi/agent/extensions/provider-router/LICENSE
test -f ~/.pi/agent/extensions/provider-router/README.md
pi -p "echo hi" 2>&1 | tee /tmp/pi-provider-router-smoke.log
! grep -i "failed to load" /tmp/pi-provider-router-smoke.log
jq '.garfield' ~/.pi/agent/extensions/provider-router/agents.json
jq '.donatello' ~/.pi/agent/extensions/provider-router/thinking.json
```

## Current Validation Status

Nix evaluation verifies the generated `agents.json` and `thinking.json` bytes.
A live Pi session still needs `home-manager switch` and a fresh Pi session, or
`/reload` in an existing session, before it can exercise the deployed files.
Do not treat this README as evidence that an interactive Pi session has passed
provider-routing checks.

## Licence
BlueOak Model License 1.0.0; see `LICENSE`.
