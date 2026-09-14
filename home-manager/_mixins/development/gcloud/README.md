# Google Cloud and Workspace

This module supplies `google-cloud-sdk`, a `gws` wrapper, and `jq` for users with the `developer` tag on hosts with the `cg` tag.
The wrapper uses the active gcloud account for Docs, Sheets, and Slides.
It replaces the separate Workspace desktop OAuth login.

The assistant composer supplies Workspace skills under the same tag gate.
Skill availability does not grant API access.
See the [skill source and refresh notes](../../agentic/assistants/gws.md).

## Authentication

After you apply the Home Manager configuration, run `mint-tokens` outside Fence.
The helper checks gcloud user credentials, Application Default Credentials (ADC), and full Drive consent.
When repair is necessary, it runs at most one login:

```bash
gcloud auth login --update-adc --enable-gdrive-access --force
```

Accept the requested Drive access for the intended account.
`--force` requests consent even when the existing gcloud token remains valid.
`mint-tokens --headless` adds `--no-launch-browser` to gcloud login.
`mint-tokens --force` requests login regardless of credential validity.

The approved Workspace scope is `https://www.googleapis.com/auth/drive`.
It permits read-write access to existing Drive files, including Docs, Sheets, and Slides, subject to file permissions.
It also permits file deletion. This is full Drive access, not the app-limited `drive.file` scope.
The gcloud login retains its normal Cloud and identity scopes. It does not request Gmail or Calendar access.

The helper verifies the exact full Drive scope through Google's [OAuth2 tokeninfo method](https://googleapis.dev/nodejs/googleapis/latest/oauth2/interfaces/Params$$Tokeninfo.html).
That method uses POST with an `access_token` query parameter. The helper passes the token to curl through standard input, not command arguments.
It then calls the read-only [Drive about method](https://developers.google.com/workspace/drive/api/reference/rest/v3/about/get) with `fields=kind`.
The about check alone does not prove full Drive consent.
Both HTTP checks have connection and total time limits. The helper suppresses response bodies and tokens.

A missing Drive scope triggers consent repair. Network failures, API failures, and malformed scope responses stop the flow without automatic login retries.
After login, the helper verifies ADC and Drive access again before it continues to Chainguard, MCP, and Docker.
If consent remains absent, check organisation policy with your administrator.
If an API check fails, check connectivity and API availability before you retry.
These checks do not prove that every Docs, Sheets, or Slides API is enabled, or that a particular file permits access.

## Automatic token refresh

Each `gws` invocation requests a fresh access token from the absolute gcloud executable, with a 30-second limit.
The wrapper exports that token as `GOOGLE_WORKSPACE_CLI_TOKEN`, replacing any stale inherited value.
It then executes the absolute upstream `gws` executable with the original arguments and exit status.
It does not start browser login, write tokens to disk, or use a separate Workspace refresh token.
If token retrieval fails or returns an empty value, the wrapper stops with a repair message.

Home Manager preserves `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` as `${XDG_CONFIG_HOME}/gws` for upstream configuration.
No credential contents enter the Nix store.
A desktop client JSON file and `MINT_GWS_ACCOUNT` are no longer prerequisites.
Existing Workspace credential files remain untouched. Protect those files until you decide how to retire them.
Do not run `gws auth setup`, which can create projects and enable APIs.
Fence settings and shared skills remain unchanged.

## Local tests

These tests use temporary homes and mock executables. They do not authenticate or contact account APIs.

```bash
bash home-manager/_mixins/users/martin/tokens/tests/mint-tokens-tests.sh
bash home-manager/_mixins/development/gcloud/tests/gws-tests.sh
```
