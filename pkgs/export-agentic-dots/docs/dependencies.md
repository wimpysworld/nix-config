# Dependencies

The assistant resources are plain Markdown unless a skill states another requirement in its frontmatter.

| Resource | Required dependency |
| -------- | ------------------- |
| Claude Code tree | Claude Code |
| Codex tree | Codex with agent roles and skills |
| OpenCode tree | OpenCode with JavaScript plugin support. The router was tested with OpenCode 1.18.30 |
| Pi tree | Pi 0.87.1 with TypeScript extension support |
| Pi MCP integration | `npm:pi-mcp-adapter@2.37.0` |
| Pi delegation | `npm:@tintinweb/pi-subagents@0.19.0` |
| Communication Rules scanner | Python 3 standard library |
| `diagram-design` skill | Python 3, with a browser and Playwright optional |
| `nix` skill | Nix |
| `gh` skill | GitHub CLI |
| `semgrep` skill | Semgrep |

Context7 needs `CONTEXT7_API_KEY`. Linear needs `LINEAR_API_KEY`. No credential value is included.

The provider-router integrations use the route maps beside their source files. The Pi prompt display extension also uses the Pi provider router.

The tested versions are evidence, not compatibility limits. Exact model routes require matching recipient access. Edit `routes.json`, `agents.json`, and `thinking.json` when the recipient uses different providers or models.

The review bundle omits `make-pr`, `post-comment`, and `wtb` because their full flows need unavailable helpers. Other resources can still name `gh-api-safe`, `gh-review-reply`, `gh-review-resolve`, `slack`, or `slack-post`. Treat those resources as review material until the recipient supplies each dependency.
