# Provider Router

Provider Router is a local Pi extension for subagent model routing. It
intercepts Pi `tool_call` events for the `subagent` tool. When the requested
subagent has a model for the active provider, it writes `params.model` in Pi's
canonical `provider/id` form. It only rewrites calls where `model` is unset. Pi
then hands the call to `pi-subagents`.

## Deployed Scope

Home Manager deploys the extension under
`~/.pi/agent/extensions/provider-router/`. The directory contains `agents.json`,
`index.ts`, `LICENSE`, and `README.md`.

`index.ts` is the runtime extension. `agents.json` is generated from assistant
`header.pi.yaml` files. The runtime reads it from
`~/.pi/agent/extensions/provider-router/agents.json`.

## Map Format

`agents.json` is an object keyed by agent name. Each agent value is an object
keyed by provider name. Each provider value is the model id for that provider.

```json
{
  "garfield": {
    "anthropic": "claude-haiku-4-5",
    "google": "gemini-3-flash",
    "openai": "gpt-5-mini"
  }
}
```

For an Anthropic parent session, the runtime writes
`anthropic/claude-haiku-4-5`.

## Declaration Format

Declare provider-specific models in an agent's `header.pi.yaml`:

```yaml
model-anthropic: claude-haiku-4-5
model-openai: "gpt-5-mini"
model-google: 'gemini-3-flash'
```

The provider name is the suffix after `model-`. The harvester accepts plain
scalar values. It also accepts matching single or double quotes and strips them.
It ignores empty values, block scalars, anchors, aliases, unmatched quotes, and
unquoted values containing `:`. v1 does not validate provider names at
evaluation time. A typo becomes a map key that never matches the active Pi
provider.

## Runtime Constraints

Provider Router covers the LLM tool-call path only. It rewrites `subagent`
calls produced by the model during a Pi session. It does not cover slash
commands such as `/run`, `/chain`, `/parallel`, or `/run-chain`. It does not
cover prompt-template-bridge invocations. v1 has no per-project override.

The runtime never overwrites an existing `model` field. Explicit model choices
in a tool call take precedence. The runtime checks
`ctx.modelRegistry.find(provider, modelId)` before writing the routed model.
Only models available to the authenticated Pi session are used.

## Graceful No-Ops

Three miss paths leave `params.model` unchanged:

1. The agent is absent from `agents.json`.
2. The agent has no entry for the active provider.
3. The mapped model is not authenticated locally.

In all three cases, `pi-subagents` receives the original call. Its resolver then
falls through to `agentConfig.model` from frontmatter. If that is absent, it
inherits the parent model.

If `agents.json` cannot be read or parsed, the extension uses an empty map. That
makes every lookup follow the first miss path.

## Freshness

The extension loads the map at startup. It refreshes the map on Pi
`session_start` and `resources_discover` events. Long-running sessions may not
see an out-of-band `home-manager switch`. Run `/reload` or restart the Pi
session after changing `agents.json`.

## Verification

Check that Home Manager's evaluated bytes match the deployed map:

```sh
nix eval --raw .#homeConfigurations.\"martin@skrye\".config.home.file.\".pi/agent/extensions/provider-router/agents.json\".text > /tmp/router-eval.json
diff /tmp/router-eval.json ~/.pi/agent/extensions/provider-router/agents.json
```

Check deployed files and smoke-test Pi extension loading:

```sh
test -f ~/.pi/agent/extensions/provider-router/agents.json
test -f ~/.pi/agent/extensions/provider-router/index.ts
test -f ~/.pi/agent/extensions/provider-router/LICENSE
test -f ~/.pi/agent/extensions/provider-router/README.md
pi -p "echo hi" 2>&1 | tee /tmp/pi-provider-router-smoke.log
! grep -i "failed to load" /tmp/pi-provider-router-smoke.log
jq '.garfield' ~/.pi/agent/extensions/provider-router/agents.json
```

## Current Validation Status

Task 3.2 passed rewrite and no-op checks with a mocked Pi runtime harness. Task
3.3 proved evaluation-side byte equivalence with a temporary source workaround
that included the untracked Garfield seed. Live deployed file checks remain
blocked in this sandbox. `home-manager switch` has not been run here.
The Garfield seed was covered only through that workaround. Do not treat this
README as evidence that a real interactive Pi session has passed
provider-routing checks.

## Licence
BlueOak Model License 1.0.0; see `LICENSE`.
