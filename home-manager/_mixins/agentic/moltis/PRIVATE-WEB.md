# Private Moltis web access on momin

This configuration prepares Moltis for private Tailscale Serve access. It does not create a mapping or activate services.

## Ownership and persistence

Martin owns the persistent Serve mapping through the installed Tailscale app, outside Fence. Do not enable Moltis's native Serve or Funnel manager.
The gateway's launchd agent starts `moltis-fenced`. A manager started by that gateway inherits Fence restrictions.
The embedded CLI works in the operator's normal login session. It failed to load preferences in the agent context. The exact cause is unconfirmed.
A separate launchd manager's access is untested, so this configuration does not install one.

The existing `org.moltis.gateway` agent retains `RunAtLoad` and `KeepAlive`.
Tailscale owns the `serve --bg` mapping and restores it when Tailscale starts. Enable Tailscale's launch-at-login setting through the app.
Availability requires login, an awake Mac, and a connected tailnet. This is not pre-login service support.

## Authentication and TLS

Only momin receives the SOPS bootstrap secret `MOLTIS_PASSWORD_TRAYA` from `secrets/moltis-web.yaml`.
The launcher waits for the runtime secret file, reads it without tracing, and rejects passwords shorter than 12 characters.
The password is not in generated TOML, a launchd plist, command arguments, or the Nix store.
Moltis receives it through `MOLTIS_PASSWORD`. Treat the process environment as sensitive.

In Moltis 20261023.01, `prepare_core.rs` calls `set_initial_password` only when credential setup is incomplete.
This is bootstrap, not password rotation. Replacing the SOPS value does not replace an existing database password.
Do not delete the credential database to force bootstrap. Use Moltis's supported account settings for later changes.

`MOLTIS_BEHIND_PROXY=true` prevents the loopback proxy connection from receiving local-development authentication bypass.
`MOLTIS_ALLOW_TLS_BEHIND_PROXY=true` retains HTTPS upstream deliberately.
Moltis stays at `127.0.0.1:13131` with TLS enabled. Port 13132 is the redirect/CA listener, not the UI backend.
Serve uses `https+insecure://localhost:13131`, the installed CLI's supported self-signed upstream form.
The certificate exception applies only to this loopback hop. Browser-facing Tailscale HTTPS must validate normally.
The separate sandbox CONNECT proxy is outside this change. Never publish its port through Serve.

## Operator activation

Run these steps in a normal, unfenced login session on momin. Stop on any failed check.

1. Inspect this device's Serve state before activation:

   ```sh
   /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status --json
   ```

   Save the output privately for comparison. Confirm that no route already exposes Moltis without authentication.
   Confirm that HTTPS port 443 is unused and that Funnel is off. If the port is occupied, stop rather than overwrite it.
   Do not use `serve reset`, `--yes`, or Funnel. Review any consent prompt before proceeding.
   Check that MagicDNS, HTTPS certificates, and tailnet access rules permit only the intended devices/users.

2. Build the reviewed configuration:

   ```sh
   just build-home martin momin
   ```

3. Activate only when ready for the existing activation hook to restart Moltis:

   ```sh
   just switch-home martin momin
   ```

4. Verify authentication locally before creating any mapping:

   ```sh
   curl --fail --silent --show-error --insecure https://127.0.0.1:13131/api/auth/status
   ```

   Require `auth_disabled=false`, `has_password=true`, `setup_complete=true`, and unauthenticated access without a session.
   A successful `/health` response is not authentication proof.
   Use a fresh browser at the local HTTPS URL. Confirm that protected content requires login and that password login succeeds.
   Retrieve the SOPS password through a secure local workflow. Do not print it in a terminal transcript or pass it in command arguments.
   If setup was already complete, verify the existing credential instead. Do not assume that the bootstrap value replaced it.

5. Recheck Serve status immediately before adding the mapping. Only when 443 remains unused, run:

   ```sh
   /Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https=443 https+insecure://localhost:13131
   /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status --json
   ```

   Confirm that only the new private mapping changed, that its upstream is correct, and that Funnel remains off.
   Record the displayed tailnet URL and mapping ownership. Do not expose ports 13132 or 18791.

6. From the phone and laptop on Tailscale, verify trusted HTTPS and login in a fresh browser.
   Verify that unauthenticated protected API and WebSocket requests fail.
   Test chat streaming, WebSocket reconnect, and logout. Register passkeys against the stable tailnet hostname, not localhost.
   Confirm that a device without tailnet access cannot connect.
   After separately approved restarts, verify recovery after Moltis restart, Tailscale restart, reboot plus login, and sleep/wake.

## Rollback

Remove the new mapping before reverting authentication or proxy settings.
Inspect `serve status --json` first and confirm that the mapping still belongs to this deployment.
For the dedicated port 443 mapping above, the targeted disable command is:

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --https=443 off
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status --json
```

Check the installed help before rollback. Do not use a global reset or remove unrelated mappings.
If another operator changed this port, stop and reconcile ownership instead.
Then activate the previous Home Manager generation if required. Keep the credential database and encrypted secret.
Removing the environment variable does not remove the password stored by Moltis.

## Validation boundary

Static checks cover host gating, runtime secret loading, missing/short-secret failure, proxy flags, TLS settings, and existing launchd persistence.
They do not establish live Tailscale state, successful bootstrap, remote login, WebSocket behaviour, or restart recovery.
Deployment validation belongs to the operator steps above. No activation, restart, mapping, or account change is part of this implementation.
