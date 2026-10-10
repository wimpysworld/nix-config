# Dependencies

The assistant resources are plain Markdown unless a skill states another requirement in its frontmatter.

| Resource | Required dependency |
| -------- | ------------------- |
| Claude Code tree | Claude Code |
| Codex tree | Codex with agent roles and skills |
| OpenCode tree | OpenCode with JavaScript plugin support. The router was tested with OpenCode 1.18.30 |
| Pi tree | Pi 1.1.0 or later with TypeScript extension support |
| Pi MCP integration | `git:github.com/nicobailon/pi-mcp-adapter@80fcdef8d9f6958751f1e225f88b272440caa542`, Git, and npm |
| Pi delegation | `npm:@tintinweb/pi-subagents@0.20.0` |
| Communication Rules scanner | Python 3 standard library |
| `diagram-design` skill | Python 3, with a browser and Playwright optional |
| `nix` skill | Nix |
| `gh` skill | GitHub CLI |
| `semgrep` skill | Semgrep |

The adapter uses an exact Git commit with Pi 1.0 support and the host peer dependency fix. Pi installs its runtime dependencies and keeps the checkout at that revision during updates. The export disables `builtin:mcp` and uses `mcp-adapter.json` for adapter settings, including `scriptMode: true` and `scriptSkill: "model"`.

Context7 needs `CONTEXT7_API_KEY`. Linear needs `LINEAR_API_KEY`. No credential value is included.

The provider-router integrations use the route maps beside their source files. The Pi prompt display extension also uses the Pi provider router.

The tested versions are evidence, not compatibility limits. Exact model routes require matching recipient access. Edit `routes.json`, `agents.json`, and `thinking.json` when the recipient uses different providers or models.

The review bundle omits `make-pr`, `post-comment`, and `wtb` because their full flows need unavailable helpers. Other resources can still name `gh-api-safe`, `gh-review-reply`, `gh-review-resolve`, `slack`, or `slack-post`. Treat those resources as review material until the recipient supplies each dependency.
