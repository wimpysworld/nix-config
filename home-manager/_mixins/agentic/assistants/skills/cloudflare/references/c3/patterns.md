# C3 Usage Patterns

## Quick Workflows

For framework apps, follow [Framework Setup](README.md#framework-setup).

```bash
# TypeScript API Worker
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts --deploy

# Astro static site\
npm create cloudflare@latest my-blog -- --framework=astro --platform=pages --lang=ts
```

## CI/CD (GitHub Actions)

```yaml
- name: Deploy
  run: npm run deploy
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

**Template selection for automation:** Choose `--type=<identifier>` for a built-in template, `--framework=<identifier>` for a framework, or `--template=<source>` for an external template. `--framework` sets `--category=web-framework` and does not require `--type`.

```bash
--no-git             # Recommended (CI already in git)
--no-deploy          # Deploy separately with secrets
--lang=ts            # For templates with language selection. Use --lang=js for JavaScript.
```

Framework creation tools can require additional answers. Check the chosen framework guide before assuming that a command is non-interactive.

## Monorepo

C3 detects workspace config (`package.json` workspaces or `pnpm-workspace.yaml`).

```bash
cd packages/
npm create cloudflare@latest my-worker -- --type=hello-world --lang=ts --no-deploy
```

## Custom Templates

```bash
# GitHub repo
npm create cloudflare@latest -- --template=username/repo
npm create cloudflare@latest -- --template=cloudflare/templates/worker-openapi

# Local path
npm create cloudflare@latest my-app -- --template=../my-template
```

**Template requires `c3.config.json`:**
```json
{
  "name": "my-template",
  "category": "hello-world",
  "copies": [{ "path": "src/" }, { "path": "wrangler.jsonc" }],
  "transforms": [{ "path": "package.json", "jsonc": { "name": "{{projectName}}" }}]
}
```

## Existing Projects

```bash
# Clone a deployed Worker into a local project
npm create cloudflare@latest my-local-worker -- --type=pre-existing --existing-script=my-worker
```

For existing framework apps, follow [Framework Setup](README.md#framework-setup).

## Post-Creation Checklist

1. Review `wrangler.jsonc` - set `compatibility_date`, verify `name`
2. With explicit authority for each remote operation, create the required resources using these command templates. Replace each placeholder with the intended resource name:
   - `wrangler kv namespace create <NAMESPACE_NAME>`
   - `wrangler d1 create <DATABASE_NAME>`
   - `wrangler r2 bucket create <BUCKET_NAME>`
3. Generate types: `npm run cf-typegen`
4. Test: `npm run dev`
5. Deploy: `npm run deploy`
6. Set secrets: `wrangler secret put SECRET_NAME`
