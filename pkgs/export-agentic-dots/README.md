# agentic-dots

This export is a review bundle of public assistant resources and portable client configuration from `nix-config`.

The bundle is not a fully equivalent working installation. It does not install or activate files, credentials, private models, host wrappers, or deferred helpers.

Copy a client tree only after you review its resources, dependencies, route map, and omissions.

## Layout

| Client | Portable root |
| ------ | ------------- |
| Claude Code | `claude/.claude` |
| Codex | `codex/.codex` |
| OpenCode | `opencode/.config/opencode` |
| Pi | `pi/.pi/agent` |

Read [the installation guide](docs/install.md), [the dependency list](docs/dependencies.md), and [the security policy](docs/security.md).

The bundle omits `make-pr`, `post-comment`, and `wtb`. Those workflows require unavailable review, GitHub, or Slack helpers. It also omits `babysit-pr`, so the portable global instructions make no monitoring or sandbox claims.

`catalogues/resources.json` records the public allowlist and deferred resource classes. `.agentic-dots-manifest.json` records every owned output, its mode, dependencies, source revision, and SHA-256 hash.
