# Dependencies

The assistant resources are plain Markdown unless a skill states another requirement in its frontmatter.

| Resource | Required dependency |
| -------- | ------------------- |
| Claude Code tree | Claude Code |
| Codex tree | Codex with agent roles and skills |
| OpenCode tree | OpenCode with JavaScript plugin support. The router was tested with OpenCode 1.18.30 |
| Pi tree | Pi 1.1.0 or later with TypeScript extension support |
| Pi MCP integration | `git:github.com/nicobailon/pi-mcp-adapter@0beff98460567cd228ae08d99db5f169a1ad3034`, Git, and npm |
| Pi delegation | `npm:@tintinweb/pi-subagents@0.26.2` |
| Communication Rules scanner | Python 3 standard library |
| `diagram-design` skill | Python 3, with a browser and Playwright optional |
| `nix` skill | Nix |
| `gh` skill | GitHub CLI |
| `semgrep` skill | Semgrep |

The adapter uses the exact `v7.0.1` Git commit. Pi installs its runtime dependencies and keeps the checkout at that revision during updates. The export disables `builtin:mcp` and uses `mcp-adapter.json` for adapter settings.

Context7 needs `CONTEXT7_API_KEY`. Linear needs `LINEAR_API_KEY`. No credential value is included.

The provider-router integrations use the route maps beside their source files. The Pi prompt display extension also uses the Pi provider router.

The tested versions are evidence, not compatibility limits. Exact model routes require matching recipient access. Edit `routes.json`, `agents.json`, and `thinking.json` when the recipient uses different providers or models.

The review bundle omits `make-pr`, `post-comment`, and `wtb` because their full flows need unavailable helpers. Other resources can still name `gh-api-safe`, `gh-review-reply`, `gh-review-resolve`, `slack`, or `agent-slack`. Treat those resources as review material until the recipient supplies each dependency.
