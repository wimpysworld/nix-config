# Roamgate

[Roamgate](https://github.com/powerfooI/roamgate) is a browser and phone client for Herdr workspaces, panes, agents, files, diffs, and Git worktrees. It can type into every pane and read any file of the user. Hosts with the `roamgate` tag in `lib/registry-systems.toml` run it, which are `skrye` and `zannah`. No other host runs it. Each host publishes Roamgate through a Cloudflare Tunnel, Caddy, and Tinyauth. The [Herdr README](README.md) documents the Herdr server.

## URLs

| Host | Roamgate URL | Tinyauth URL |
| --- | --- | --- |
| skrye | `https://herdr-skrye.wimpys.world` | `https://auth-skrye.wimpys.world` |
| zannah | `https://herdr-zannah.wimpys.world` | `https://auth-zannah.wimpys.world` |

Each host is its own origin, so log in and install the app on each host separately. Tinyauth at `https://auth-<host>.wimpys.world` is the single login screen (username `martin`, `ROAMGATE_PASSWORD`, and your TOTP code). After Tinyauth approves a session, `https://herdr-<host>.wimpys.world` opens directly into Herdr with no second login prompt.

Local access to `http://localhost:8787` and `http://127.0.0.1:8787` is blocked by the NixOS firewall for every local user except `caddy`, so fenced agents cannot reach Roamgate directly.

## Parts

| Part | Source |
| --- | --- |
| Package: built from source, with a fixed-output `node_modules` | [pkgs/roamgate/default.nix](../../../../pkgs/roamgate/default.nix) |
| User service, sops decryption, the env file, and the Ranger provider merge | [home-manager/_mixins/terminal/herdr.nix](../herdr.nix) |
| System services: Tinyauth, Caddy virtual hosts, and `cloudflared-roamgate` | [nixos/_mixins/server/roamgate/default.nix](../../../../nixos/_mixins/server/roamgate/default.nix) |
| Fence read and write denial | [home-manager/_mixins/agentic/fence/default.nix](../../../../home-manager/_mixins/agentic/fence/default.nix) |
| Freshener job | [.github/freshener/roamgate.sh](../../../../.github/freshener/roamgate.sh) |

The server runs outside Fence as the `roamgate.service` systemd user service, on `127.0.0.1:8787`, with `Restart=on-failure` and `NODE_ENV=development`. Setting `NODE_ENV=development` on a loopback bind disables Roamgate's built-in login screen so Tinyauth is the sole login gate. It starts after `herdr.service` and connects to the Herdr sockets directly. It is not the Roamgate Herdr plugin, which downloads a prebuilt binary, so do not run `herdr plugin install` or `herdr plugin link` for it. It runs from source on Bun, so the self-updater cannot replace it, and `ROAMGATE_DISABLE_UPDATE_CHECK=1` turns off update checks (see [Browser settings](#browser-settings)).

NixOS configures the loopback firewall rule in `nixos/_mixins/server/roamgate/default.nix` so only the `caddy` system user can connect to loopback TCP port `8787`. When `TINYAUTH_AUTH_USERS` exists in `secrets/roamgate.yaml`, NixOS also enables Tinyauth and Caddy. `tinyauth.service` listens on `127.0.0.1:8789` for `https://auth-<host>.wimpys.world` with secure cookies, a 30-day session expiry (`AUTH_SESSIONEXPIRY = 2592000`), and a 300-second lockout after 3 failed logins. `caddy.service` binds `127.0.0.1:8788` for both `auth-<host>.wimpys.world` and `herdr-<host>.wimpys.world`, and logs to `/var/log/caddy/roamgate.log`. Caddy proxies `auth-<host>.wimpys.world` to Tinyauth on `127.0.0.1:8789`. For `herdr-<host>.wimpys.world`, Caddy runs `forward_auth` against `127.0.0.1:8789/api/auth/caddy`, then proxies traffic to Roamgate on `127.0.0.1:8787`. Both virtual hosts forward `X-Forwarded-Proto: https` and `X-Forwarded-For` from `CF-Connecting-IP`.

`cloudflared-roamgate.service` starts after `caddy.service` and `tinyauth.service`, and requires both units. It runs `cloudflared tunnel --no-autoupdate run --token-file` with the host's tunnel token. NixOS enables `cloudflared-roamgate.service` only when both `TINYAUTH_AUTH_USERS` and `CLOUDFLARE_TUNNEL_TOKEN_ROAMGATE_<HOST>` exist in `secrets/roamgate.yaml`.

State is in `~/.config/roamgate/`: the env file `roamgate.env`, the session secret, settings, connection profiles, push keys, Ranger data, and uploads. Roamgate refuses a symlink in that path, so Home Manager links no file into it. Fence denies reads and writes of this directory and of the legacy `~/.config/herdr-gui/`, because the session secret signs a cookie that opens every route of the server.

## Login and secrets

Tinyauth is the sole authentication layer (username `martin`, `ROAMGATE_PASSWORD`, and a shared TOTP secret, with 30-day sessions). Roamgate runs with `NODE_ENV=development` on `127.0.0.1:8787` and accepts connections only from the `caddy` system user.

Each Home Manager activation decrypts `OPENCODE_API_KEY` from `secrets/ai.yaml` with `sops` and the user's age key, then writes `~/.config/roamgate/roamgate.env` with mode 0600. sops-nix does not render that user value, because Fence keeps `~/.config/sops-nix` readable. NixOS renders the Tinyauth and Cloudflare Tunnel secrets from `secrets/roamgate.yaml` with sops-nix as `root` with mode 0400.

| File | Key | Consumer | Value |
| --- | --- | --- | --- |
| `secrets/ai.yaml` | `OPENCODE_API_KEY` | `OPENCODE_API_KEY` in `~/.config/roamgate/roamgate.env` | Workspace API key for the OpenCode Go subscription, for [Ranger](#ranger). |
| `secrets/roamgate.yaml` | `ROAMGATE_PASSWORD` | [sync-tinyauth.sh](../../../../nixos/_mixins/server/roamgate/sync-tinyauth.sh) | Shared Tinyauth password across `skrye` and `zannah`. |
| `secrets/roamgate.yaml` | `TINYAUTH_AUTH_USERS` | `tinyauth.service` via sops template `tinyauth-roamgate.env` | Tinyauth user credential (`martin:<bcrypt-hash-of-ROAMGATE_PASSWORD>:<totp-secret>`), shared across `skrye` and `zannah`. |
| `secrets/roamgate.yaml` | `TINYAUTH_TOTP_URI` | Local operator setup | `otpauth://` URI for adding the shared TOTP secret to an authenticator app or password manager. |
| `secrets/roamgate.yaml` | `CLOUDFLARE_TUNNEL_TOKEN_ROAMGATE_<HOST>` | `cloudflared-roamgate.service` (`--token-file`) | Per-host Cloudflare Tunnel token (`CLOUDFLARE_TUNNEL_TOKEN_ROAMGATE_SKRYE`, `CLOUDFLARE_TUNNEL_TOKEN_ROAMGATE_ZANNAH`). |

Run [sync-tinyauth.sh](../../../../nixos/_mixins/server/roamgate/sync-tinyauth.sh) to update `TINYAUTH_AUTH_USERS` from `ROAMGATE_PASSWORD` and the existing TOTP secret (pass `--qr` to display the TOTP QR code):

```sh
./nixos/_mixins/server/roamgate/sync-tinyauth.sh
```

If the age key is missing, a file or key is missing, decryption fails, or `OPENCODE_API_KEY` is empty, activation prints a `roamgateEnv` warning with the reason and leaves the old file. Activation also warns when the file is still missing. Without the file, the pre-start check fails and logs `missing ~/.config/roamgate/roamgate.env`.

Sign in through Tinyauth with username `martin`, `ROAMGATE_PASSWORD`, and your TOTP code. The Tinyauth session lasts 30 days. To rotate the password, change `ROAMGATE_PASSWORD` in `secrets/roamgate.yaml`, run `./nixos/_mixins/server/roamgate/sync-tinyauth.sh`, then run `just switch-host`. To rotate a Cloudflare Tunnel token, update `secrets/roamgate.yaml`, then run `just switch-host`.

## Worktree hooks

Roamgate can run worktree hooks from a `roamgate.json` or `paseo.json` file in a repository, outside Fence. Upstream runs them unless a repository turns them off. The package changes that default, so hooks are off for every repository. A hook runs only after you enable hooks for that repository in the Roamgate settings. Do not enable hooks for a repository that a fenced agent can write to, because the agent can then write a hook. Fence cannot deny writes to these files.

## Ranger

Ranger is the built-in assistant. It runs on the Pi SDK inside the Roamgate server and uses the built-in `opencode-go` provider (OpenCode Go) with the OpenCode Go subscription. Leave automatic approval off.

| Setting | Value | Where |
| --- | --- | --- |
| Provider | `opencode-go` | `config.provider` in `~/.config/roamgate/assistant/state.json` |
| Model | `glm-5.3-flash` | `roamgateRangerModel` in [herdr.nix](../herdr.nix), written to `config.model` |
| Credential source | `assistant`, the separate Ranger store | `config.credential_source` |
| API key | `$OPENCODE_API_KEY` | `providers.opencode-go.apiKey` in `~/.config/roamgate/assistant/models.json` |
| Endpoint | `https://opencode.ai/zen/go/v1` | The Pi SDK model list. MiniMax and Qwen Flash models use `https://opencode.ai/zen/go` with the Anthropic API. |

Roamgate reads the provider and the model from `state.json`, not from the environment or `settings.json`. It counts a provider as configured only when `auth.json` holds a key or `models.json` names the key's environment variable. `models.json` holds the variable name, not the key. The key comes from `OPENCODE_API_KEY` in the env file, which is the variable that the `opencode-go` provider reads.

Roamgate rewrites `state.json` from memory while it runs, so the `roamgate-ranger-config` pre-start step merges these values before each start. It keeps the conversations and all other keys. It drops the thinking effort only when the model changes, because Ranger refuses an effort that the model does not support. A file that is not a JSON object stays unchanged with a warning in the unit log, and the server still starts. A model or provider that you choose in the Ranger settings lasts until the next start of `roamgate.service`. To change the model for good, set `roamgateRangerModel` to another ID from the [OpenCode Go model list](https://opencode.ai/docs/go/), then run `just switch-home`.

Ranger reads workspace status, pane history, and terminal output only in the workspaces that you allow for a turn. It cannot run shell commands or read files. It can propose workspace, worktree, tab, pane, and agent operations, prompts to agents, scheduled tasks, and notifications, and it runs them only after you confirm them. Each turn sends your messages, the system prompt, and the tool results, including the pane and terminal text that it reads, to OpenCode at `opencode.ai`. Keep secrets out of panes in an allowed workspace.

## Browser settings

The **Behavior** tab of the Roamgate settings applies to the browser only. Roamgate keeps these values in the browser's `localStorage`, not in `~/.config/roamgate/settings.json`, and no environment variable sets their defaults. Set them once in each browser and on each device.

| Setting | Default | Server side |
| --- | --- | --- |
| **Automatic update checks** | Enabled | The unit sets `ROAMGATE_DISABLE_UPDATE_CHECK=1`. The server then answers every check with no update and makes no network request, but the toggle still shows **Enabled**. Turn it off to stop the check every 30 minutes. |
| **Task notifications** | Off | The browser must grant the notification permission, and only a click in the page can ask for it. Server push is on by default, with a VAPID key in `~/.config/roamgate/web-push.json`. An empty `ROAMGATE_WEB_PUSH_SUBJECT` turns push off, so the unit does not set it. |
| **Task needs attention**, **Task completed** | On, when task notifications are on | None. |

Task alerts follow Herdr's own notifications, because `ROAMGATE_NOTIFICATION_SOURCE` defaults to `herdr` and Herdr is 0.9 or later. `[ui.notifications] external_agents` in the Herdr configuration also controls the Roamgate alerts.

## Upgrades

The freshener opens a pull request for each upstream `vX.Y.Z` release. The release rate is high, so expect several pull requests each week. The build fails when a release changes the hook default lines that the package patches, or when the server imports a package outside the pruned `node_modules`. Add that package to the `prune-node-modules.ts` call in the package.

Upstream declares Bun 1.4.3. The flake has Bun 1.4.2, and the build and a short run pass with it.

## Set up

1. Create one Cloudflare Tunnel per host (`skrye` and `zannah`). Route both `herdr-<host>.wimpys.world` and `auth-<host>.wimpys.world` to `http://127.0.0.1:8788`.
2. Check that `secrets/roamgate.yaml` holds `ROAMGATE_PASSWORD`, `CLOUDFLARE_TUNNEL_TOKEN_ROAMGATE_SKRYE`, `CLOUDFLARE_TUNNEL_TOKEN_ROAMGATE_ZANNAH`, `TINYAUTH_AUTH_USERS`, and `TINYAUTH_TOTP_URI`, and `secrets/ai.yaml` holds `OPENCODE_API_KEY`.
3. Run `./nixos/_mixins/server/roamgate/sync-tinyauth.sh --qr` to sync `TINYAUTH_AUTH_USERS` with `ROAMGATE_PASSWORD` and scan the displayed TOTP QR code into your authenticator app.
4. Run `just switch-host` and `just switch-home` on `skrye` and on `zannah`.
5. Open `https://herdr-skrye.wimpys.world` or `https://herdr-zannah.wimpys.world`. Sign in once through Tinyauth at `https://auth-<host>.wimpys.world` with username `martin`, `ROAMGATE_PASSWORD`, and your TOTP code.
6. Add the app to the Home Screen on the phone, so that web push works.
7. In each browser and in the phone app, open the settings, then the **Behavior** tab. Turn off **Automatic update checks**.
8. On the same tab, turn on **Task notifications** and allow notifications when the browser asks. Wait until the status shows **On · Background push**.
