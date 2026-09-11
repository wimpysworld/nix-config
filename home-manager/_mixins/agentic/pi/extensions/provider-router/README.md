# Provider Router

Provider Router selects models for explicit Pi tasks without changing the inference
provider. Home Manager generates its maps from unified `header.toml` metadata.

## Precedence

The first available selection wins for each task:

1. An explicit caller model or a user model selection.
2. A command route.
3. A directly invoked skill route.
4. An agent route.
5. The session model.

`--model` and native user model changes take priority for the rest of the session.
A workflow child can supply its own `model`. The router validates that model and
preserves its selection. Routes cannot select a different inference provider.

## Direct commands and skills

The native `input` event handles `/command` and `/skill:name`. The local
`prompt-template-display` extension calls the same dispatcher before it consumes
TUI command input. Both paths validate and stage the route without changing the
session model. At `before_agent_start`, after prompt preflight, the router applies
the route through Pi's `setModel` and `setThinkingLevel` APIs.

Routed input requires an idle session. The router rejects routed steering and
follow-up input with an error. Unrouted input keeps its existing behaviour.
After `agent_settled`, the router restores the previous session model and thinking
level. Routes remain active through retries and overflow recovery.
A user model change cancels restoration and takes priority over later routes.
Children launched during the task inherit its command or directly invoked skill
route, unless the caller supplies a model or a more specific command.

Reading a supporting `SKILL.md` never selects a model. The `skills` list on a
child task also does not select a model.

## Workflow children

The `subagent` tool hook wraps `runs.run` and `runs.all`. Each child specification
is resolved immediately before its launch. Top-level `await`, `return`, dynamic
specifications, and the other `runs` methods remain available.

A child can declare `command: "review-code"` or `directSkill: "research-task"`
to request a route. The wrapper removes these routing fields before native child
validation. These fields select routing metadata. They do not expand prompt
content, so the caller must also supply the task instructions.

Legacy single calls, `tasks`, chain steps, parallel chain steps, and
`action: "append-step"` use the same resolver. Other management actions remain
unchanged. External extension event-bus delegation does not pass through the
`tool_call` hook. Use the supported `subagent` workflow path for routed children.

## Generated maps

Home Manager deploys these files under
`~/.pi/agent/extensions/provider-router/`:

| File | Content |
|------|---------|
| `agents.json` | Agent name, inference provider, model ID. |
| `thinking.json` | Agent name, inference provider, thinking level. |
| `routes.json` | Command and directly invoked skill routes. |

`routes.json` has this structure:

```json
{
  "commands": {
    "review-code": {
      "agent": "penry",
      "providers": {
        "openai-codex": { "model": "gpt-5.6-terra", "thinking": "high" }
      }
    }
  },
  "skills": {
    "research-task": {
      "providers": {
        "openai-codex": { "thinking": "high" }
      }
    }
  }
}
```

Declare routes in the command, skill, or assistant's `header.toml`:

```toml
[routing.pi.openai-codex]
model = "gpt-5.6-terra"
thinking = "high"
```

Thinking-only routes use the current session model. The accepted levels are
`off`, `minimal`, `low`, `medium`, `high`, `xhigh`, and `max`. Pi's native
`getSupportedThinkingLevels` further checks support for the selected model.

## Errors and freshness

Unknown explicit command or skill route names, unavailable models, unsupported
thinking levels, and malformed map files produce errors. A command or skill with
routes but no entry for the active provider also produces an error. An agent with
no route for that provider keeps its existing behaviour.

The router uses `modelRegistry.getAvailable()` to validate authenticated models.
Tool errors return `{ block: true, reason }`, because Pi catches hook exceptions
and otherwise continues execution. Workflow errors stop the child launch.
Input errors notify the user and return `handled`.

Maps reload on `session_start` and `resources_discover`. After deploying changed
maps, use `/reload` or start a fresh session. No live session is needed for tests.

## Verification

Run the runtime and display tests with Node.js 24 or later:

```sh
node --experimental-loader ./home-manager/_mixins/agentic/pi/extensions/provider-router/test-loader.mjs \
  --experimental-loader ./home-manager/_mixins/agentic/pi/extensions/prompt-template-display/test-loader.mjs \
  --test home-manager/_mixins/agentic/pi/extensions/provider-router/*.test.mjs \
  home-manager/_mixins/agentic/pi/extensions/prompt-template-display/index.test.ts
```

Workflow tests use the installed `pi-subagents` validator and worker with mock
child launches. Set `PI_SUBAGENTS_DIR` to test another installation. Invocation
tests use mocked Pi hooks and model APIs. Set `PI_CODING_AGENT_DIR` to the installed
`@earendil-works/pi-coding-agent` package directory to include native lifecycle tests.
Those tests use Pi's agent loop and session methods with fake inference and compaction.
Tests make no model requests and do not change the active Pi session.

## Licence

BlueOak Model License 1.0.0. See `LICENSE`.
