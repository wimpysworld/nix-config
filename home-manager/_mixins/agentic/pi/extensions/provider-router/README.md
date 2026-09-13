# Provider Router

Provider Router selects models for new Pi child launches without changing the inference
provider or the root session settings. Home Manager generates its maps from unified `header.toml` metadata.

## Precedence

The first available selection wins for each new child:

1. An explicit child `model`.
2. An explicit child `command` route.
3. An explicit child `directSkill` route.
4. The named agent route.
5. The native session fallback.

Explicit child `thinking` (workflow `effort`) overrides route thinking and a model suffix.
An explicit model without thinking leaves thinking to the native runtime.
Root `--model` and user model changes do not override named agent routes.
Routes cannot select a different inference provider.

## Direct commands and skills

Commands and skills do not change the root model or thinking level.
The router acknowledges the existing `prompt-template-display` invocation event
without staging a route. Native input, retries, and settlement leave settings unchanged.
Pi and the display extension retain control of input delivery.

Children do not inherit command or skill routes from root input or earlier children.
Each new supporting specialist uses its own agent route unless its launch specifies an override.

Reading a supporting `SKILL.md` never selects a model. The `skills` list on a
child task also does not select a model.

## Native children and workflows

The router handles Tintinweb's `Agent` and `SubagentWorkflow` tools.
`Agent` receives separate `model` and `thinking` fields. Workflow `agent()` calls receive `model` and `effort`.
Every new launch must name a specialist through `subagent_type` or workflow `agentType`.
Resumed children pass through without route changes. Launch safety checks still apply.

Native `Agent` resolves agent frontmatter before tool arguments, then uses the parent fallback.
Generated agent headers leave both model and thinking unset, so routed arguments and explicit overrides take effect.
A separately installed agent with pinned frontmatter can override those arguments.
Workflow host code gives explicit `model` and `effort` priority over agent defaults.

Inline scripts, `scriptPath`, and saved `name` sources receive the same wrapper.
Source precedence matches upstream: path, inline script, then saved name.
The wrapper preserves workflow metadata, arguments, return values, `parallel`, and `pipeline`.
Each workflow has a router limit of twelve active calls. The native runtime retains its 1000-call limit per workflow.
Native CPU-based capacity can lower workflow concurrency.
The background pool, foreground pool, and each workflow have separate limits of twelve, not one global aggregate cap.
Shared instructions require the root to keep at most twelve workers active across all delegation tools and workflows combined.
This aggregate rule is guidance, not a shared scheduler.
Workflow children occupy neither direct pool. Foreground resumes can exceed their pool limit.
A failed or skipped required child fails the workflow, even when a stage catches the error.

A child can declare `command: "review-code"` or `directSkill: "research-task"`
to request a route. The wrapper removes these routing fields before native child
validation. These fields select routing metadata. They do not expand prompt
content, so the caller must also supply the task instructions.

Use the routed tools for delegation. Nested `workflow()` calls are rejected because their source bypasses the tool hook.
Launch saved workflows through `SubagentWorkflow` instead.
Agent mentions and scheduling are disabled. Do not use slash-command launch shortcuts or event-bus launches, which bypass routing.

Automatic worktrees are disabled because upstream 0.19.0 cleanup can discard changes after a preservation error.
The router rejects isolation requests rather than silently using the shared checkout.
Use separate Pi sessions in separate checkouts for concurrent writers.
Children must retain policy extensions. `isolated: true` and `extensions: false` requests fail.

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
Native workflow validation rejects `effort: "off"`, including an `off` route.
Use `off` only with native `Agent` until upstream workflow support changes.

## Errors and freshness

Unknown explicit command or skill route names, unavailable models, unsupported
thinking levels, and malformed map files produce errors. A command or skill with
routes but no entry for the active provider also produces an error. An agent with
no route for that provider keeps its existing behaviour.

The router uses `modelRegistry.getAvailable()` to validate authenticated models.
Tool errors return `{ block: true, reason }`, because Pi catches hook exceptions
and otherwise continues execution. Workflow errors stop the child launch.
Root input does not validate child routes.

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

Workflow tests use the installed `@tintinweb/pi-subagents` validator and VM with mock child launches.
Header tests evaluate all generated agents, check that model and thinking are unset, and load their symlinks through the upstream loader. Set `PI_SUBAGENTS_DIR` to test another installation. Invocation
tests use mocked Pi hooks and model APIs. Set `PI_CODING_AGENT_DIR` to the installed
`@earendil-works/pi-coding-agent` package directory to include native lifecycle tests.
Those tests use Pi's agent loop and session methods with fake inference and compaction.
Tests make no model requests and do not change the active Pi session.

## Licence

BlueOak Model License 1.0.0. See `LICENSE`.
