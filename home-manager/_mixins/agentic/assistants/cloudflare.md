# Cloudflare skills

The four skills come from [cloudflare/skills](https://github.com/cloudflare/skills/tree/c668cb2d1e28e0ba38efc73625b31732a6d5d13c/skills), revision `c668cb2d1e28e0ba38efc73625b31732a6d5d13c`.
Each directory includes the unchanged upstream Apache-2.0 `LICENSE` and records the source and revision in `header.toml`.

| Skill | Purpose |
| --- | --- |
| `cloudflare` | Product selection and documentation references |
| `wrangler` | Wrangler commands and configuration |
| `workers-best-practices` | Workers code, configuration, and review |
| `durable-objects` | Persistent state and coordination |

The import includes every supporting file from these four upstream directories, with the original relative layout.
The product references retain upstream `README.md` files and nested navigation so that the full reference set remains usable.
Optional sibling skills are not imported. Their three relative links point to the pinned upstream source instead.
Plugin manifests and their authenticated MCP configuration are not imported.

The existing composer discovers these skills for enabled Claude Code, Codex, OpenCode, and Pi clients.
Existing Moltis delivery also remains in place. Skills do not change client gates or imply that Wrangler is installed on every host.
See [the development module](../../development/cloudflare/README.md) for the package gate.
The shared MCP registry supplies the documentation-only `cloudflare-docs` endpoint and the authenticated `cloudflare-api` stdio wrapper through existing client renderers.
The API wrapper passes the shared runtime token as `API_ACCESS_TOKEN` only to `pkgs.mcp-proxy` for `https://mcp.cloudflare.com/mcp`.
The managed Wrangler wrapper reads `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` from SOPS runtime files when explicit environment overrides are absent.
Project-local Wrangler does not automatically receive these wrapper credentials. No separate MCP token or global credential export is required.
The R2 keys `CLOUDFLARE_ACCESS_KEY_ID`, `CLOUDFLARE_SECRET_ACCESS_KEY`, and `CLOUDFLARE_S3_API_ENDPOINT` remain separate from Wrangler and MCP.
Source configuration does not prove that the wrappers are active in an installed client.

## Local changes

- Move upstream frontmatter into `header.toml`. Keep each `SKILL.md` body free of frontmatter.
- Add managed-tooling and authority limits to every skill body. These limits also govern supporting references.
- Replace automatic Wrangler installation with the managed executable or an explicitly approved project dependency change.
- Refer to `cloudflare-docs` tools rather than the authenticated API server's `docs` tool.
- Clarify CLI selection: honour explicit Wrangler requests, including new projects, but stop when a project requires unapproved `cf`. Tool installation and migration need separate approval.
- Permit task-scoped reads through the authorised runtime wrappers without repeated authentication approval, including unattended reads.
- Prohibit direct credential reads, decryption, disclosure, and global exports. Require explicit approval for login, new tokens, and secret-wiring changes.
- Keep credential permissions separate from authority for mutations, remote tests, deployments, and claim deployments in the target account and environment.
- Convert optional sibling skill links to pinned upstream URLs.
- Normalise line endings and trailing whitespace. Preserve Markdown hard breaks as backslashes.
- Add contents lists to reference files longer than 100 lines where section headings exist.

Technical corrections also change the imported guidance and examples:

- C3 (create-cloudflare): correct deployed Worker cloning, category and template selection, `--lang` flags, platform applicability, and the telemetry variable. Mark framework values as examples. Clarify template-dependent prompts and automation, and repair reference links.
- C3 output and resources: use `worker-configuration.d.ts` as the default type output. Add resource-name placeholders and explicit authority requirements to resource creation commands.
- Framework bindings: link to the framework guide index rather than direct every project to Hono. Retain Hono-specific guidance for Hono projects.
- Observability: describe `persist` as persistence in Cloudflare, not local persistence.
- Durable Objects: prefer SQLite for new classes, preserve existing storage backends unless migration is authorised, and retain `fetch()` for HTTP and WebSocket flows. Correct room routing, await handlers inside error handling, remove the undefined user helper, and replace the D1 listing query with authorised API guidance.
- Workers types: accept `Response` or `Promise<Response>`, use `WorkflowEntrypoint`, and preserve required specialisations of generated environment types.
- KV selection: prefer Workers Cache for application caching. Require a concrete unmet requirement before choosing KV, with links to cache patterns and limitations.
- AI Gateway: document dynamic routes through REST `/ai/v1/chat/completions` and `env.AI.run()`, using `dynamic/<route-name>`, OpenAI chat completions requests, and explicit gateway selection. The compatibility endpoint remains supported, not required.

Feedback references in all four skills use `post-issue`, starting with `draft-issue` contribution policy, duplicate, template, and writing checks.
The feedback table supplies source information rather than replacing the repository template.
Posting requires approval of the exact title and body, repeated after changes, without a direct `gh issue create` bypass.
Repository title requirements take precedence over the suggested feedback title.

Examples are reference material, not permission to install tools, authenticate, change resources, or delete files.

## Refresh

1. Select a full upstream commit and verify that it belongs to `cloudflare/skills`.
2. Fetch its archive into a separate temporary directory. Read its README, MCP manifest, licence, and selected skill trees.
3. Compare all four directories with the local import. Do not execute upstream scripts or import plugin manifests.
4. Copy only the selected directories and root licence. Preserve every supporting file and relative path.
5. Reapply the local changes above and update each `header.toml` revision.
6. Check all relative Markdown links and bare reference paths. Resolve optional sibling links against the pinned upstream source.
7. Compare each copied licence byte-for-byte with upstream. Review all other differences against the documented adaptations.
8. Run `just update-assistant-catalogue`, then `just check-assistant-catalogue` and `git diff --check`.
9. Evaluate the package gate and all client outputs. Build only the generated skill trees and Wrangler, without activation.

## Trigger checks

| User message | Expected behaviour |
| --- | --- |
| "Which Cloudflare storage product fits file uploads?" | Load `cloudflare`, then its R2 reference. |
| "Explain this local Git rebase." | Ignore all four skills. |
| "Create a new project with cf." | Read product guidance, then stop CLI work for separate tool approval. |
| "Check the Wrangler config for this existing Worker." | Load `wrangler`. |
| "Review this Python command-line parser." | Ignore `wrangler` and Workers-specific skills. |
| "Deploy this Worker, but no credentials are configured." | Load `wrangler`, then report missing setup without login or replacement tokens. |
| "List Workers in this account." | Use an available managed runtime path for the scoped read without another authentication approval. |
| "Review this Worker without deploying it." | Read within scope, but do not infer deployment authority from token permissions. |
| "Review this Worker's streaming response." | Load `workers-best-practices`. |
| "Review this React component's layout." | Ignore `workers-best-practices` and `durable-objects`. |
| "Review the SQLite transaction in this Durable Object." | Load `durable-objects` rather than rely only on general Workers guidance. |
| "Add a Durable Object alarm for each game room." | Load `durable-objects`. |
| "Write a stateless HTTP endpoint." | Use Workers guidance, not Durable Objects unless coordination is required. |
| "Grant Data Studio access to this Durable Object." | Read authorisation guidance, then require explicit authority before account changes. |
