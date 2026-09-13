# Google Cloud and Workspace

This module supplies `google-cloud-sdk`, `gws`, and `jq` for users with the `developer` tag on hosts with the `cg` tag.
The SDK uses the standard package without the beta component. The token helper uses the same package.
The locked nixpkgs package is `gws` 0.22.5. `jq` supports the Gmail read and triage examples.

The assistant composer supplies 20 Workspace skills under the same tag gate.
Claude Code, Codex, and OpenCode also require their client enablement. Pi uses the existing developer gate, including developer servers.
See the [skill source and refresh notes](../../agentic/assistants/gws.md).

## One-time authentication

Use the existing Google Cloud project. Do not run `gws auth setup`, which can create projects and enable APIs.
The `mint-tokens` flow checks Google Cloud, Workspace, Chainguard, MCP, and Docker credentials, and repairs credentials that fail checks.
Workspace uses its own encrypted desktop login, not gcloud Application Default Credentials. The OAuth client remains a manual prerequisite.

Complete these steps yourself after you apply the Home Manager configuration:

1. Select your existing project in Google Cloud Console. Check that it is the intended project before you change it.
2. Enable the APIs that you need: Gmail, Google Calendar, Google Drive, Google Docs, Google Sheets, and Google Slides.
3. Configure the OAuth consent screen for your organisation's policy. For an external testing app, add your account as a test user.
4. Reuse a suitable **Desktop app** OAuth client in that project, or create one there. Download its client JSON.
5. Create a private directory with `install -d -m700 "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR"`.
6. Save the downloaded JSON as `$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/client_secret.json` with mode `0600`. Do not overwrite an existing file without checking it.
7. Run `mint-tokens` outside Fence. Select the active gcloud account when Google asks for an account.

For a different Workspace account, set `MINT_GWS_ACCOUNT` to its email address before you run `mint-tokens`.
The Workspace step uses this explicit scope list:

```bash
gws auth login --scopes https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/calendar,https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/presentations
```

| Service | Access |
| --- | --- |
| Gmail | Read-only. Send, reply, forward, and mailbox changes are not authorised. |
| Calendar | Read-write, including calendar sharing and deletion. |
| Drive | `drive.file`, for files created or explicitly authorised through this app. |
| Docs, Sheets, Slides | Read-write through their service APIs. These scopes are not limited to app-created files. |

Drive cannot browse or modify arbitrary existing files with `drive.file`. A known file ID alone does not authorise that file.
Full Drive access requires a separate scope decision. Do not substitute `drive` without approval.

Explicit scopes bypass the discovery picker, which adds `cloud-platform` in 0.22.5. The flow never uses `--full` or `gws auth setup`.
The CLI also adds identity scopes (`openid`, `userinfo.email`, and `userinfo.profile`).
The check rejects missing scopes and all additional scopes except these identity scopes, including older Gmail write or full Drive grants.
If an older grant persists after login, remove that app grant in your Google Account before you retry.
Organisation policies can require administrator approval. Testing-mode consent can require later reauthorisation.
Gmail `+watch` also needs Pub/Sub resources, permissions, and scopes. Approve that setup separately before you use the helper.

## Conditional renewal

The check uses `gws auth status` with a 30-second limit and suppresses its output.
In 0.22.5, status exchanges the stored refresh token, requests user identity, and obtains granted scopes from Google's tokeninfo endpoint.
It can also list enabled Cloud APIs. It does not read mail, calendar events, or file contents.
Success requires encrypted, decryptable credentials, a successful refresh, the expected email address, and the exact permitted scope set.
Status does not use the access-token cache or fall back to ADC, so those sources cannot hide a failed Workspace login.
The check does not prove that every service API is enabled or that a particular resource permits access.

When credentials pass, the flow skips login. `--force` always starts a new interactive Workspace login, followed by the same check.
Login has a five-minute limit. A failed login or post-login check stops the flow before Chainguard, MCP, and Docker steps.
After login, the helper moves any old `token_cache.json` into a private `token-cache-backup.*` directory beside it.
This preserves the old cache but prevents gws from reusing tokens for the previous account or scopes. Treat backups as credential files.
With `--headless`, valid credentials pass, but required or forced Workspace login returns an interactive-login error without starting login.
A missing client JSON blocks interactive repair with manual setup instructions. Valid stored credentials do not require that client file.
Unset token, credential-file, and OAuth client environment overrides before you run `mint-tokens`. The helper rejects these overrides without printing their values.

## Credential storage

Home Manager sets only `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` to `${XDG_CONFIG_HOME}/gws`.
No client secrets, tokens, or credential contents enter the Nix store.
The directory remains mutable and private. Do not declare credential JSON with `home.file`, `writeText`, or `sessionVariables`.

The pinned source supports these inputs:

| Input | Purpose |
| --- | --- |
| `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` | Directory for client configuration, encrypted credentials, and token cache |
| `GOOGLE_WORKSPACE_CLI_CLIENT_ID` and `GOOGLE_WORKSPACE_CLI_CLIENT_SECRET` | Paired runtime overrides for the OAuth client |
| `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` | Runtime path to compatible authorised-user or service-account JSON, not downloaded Desktop client JSON |

Prefer the private `client_secret.json` file for desktop login. Its project ID also informs the scope picker.
Existing gcloud and MCP tokens do not prove Workspace scope compatibility.
Leave token and credential-file overrides unset for normal encrypted desktop login, because they take precedence over encrypted credentials.

On Linux, the encryption key can live in `.encryption_key` beside `credentials.enc`, including as a fallback copy for keyring storage.
Anyone who obtains both files can decrypt the credentials. Protect the whole directory and its backups, including `token_cache.json` and `client_secret.json`.
Use mode `0700` for the directory and `0600` for credential files. Do not print, commit, or copy credentials into an agent transcript.

For `developer` users on `cg` hosts, Fence permits writes to the gws directory and its contents for credential storage and token-cache updates.
The existing network and Nix executable permissions cover gws. No wider permissions are added.
Complete login outside Fence. These filesystem permissions do not authorise agents to configure authentication or change Workspace data.

The pinned [authentication documentation](https://github.com/googleworkspace/cli/blob/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/README.md#authentication) describes the upstream flows.
