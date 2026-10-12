# Roamgate

[Roamgate](https://github.com/powerfooI/roamgate) is a browser and phone client for Herdr workspaces, panes, agents, files, diffs, and Git worktrees. It can type into every pane and read any file of the user. skrye and zannah run it next to [Herdr Web](herdr-web-ui.md) for a side-by-side test, and Tailscale Serve publishes it on the tailnet. No other host runs it.

## URLs

| Host | URL |
| --- | --- |
| skrye | `https://skrye.drongo-gamma.ts.net:10000` |
| zannah | `https://zannah.drongo-gamma.ts.net:10000` |

Each host is its own origin, so log in and install the app on each host separately. Funnel stays off, so the app is not on the internet.

Never open Roamgate at `http://localhost:8787` or `http://127.0.0.1:8787`, even though its log prints a `localhost` URL. The `/ws` WebSocket checks only the login cookie, not the page origin. On `localhost`, a page that a fenced agent serves on another local port is same-site, so it can use the cookie to drive the panes outside Fence.

## Parts

| Part | Source |
| --- | --- |
| Package: built from source, with a fixed-output `node_modules` | [pkgs/roamgate/default.nix](../../../../pkgs/roamgate/default.nix) |
| User services, sops decryption, the env file, the Ranger provider merge, and the Tailscale Serve unit on port 10000 | [home-manager/_mixins/terminal/herdr.nix](../herdr.nix) |
| Fence read and write denial | [home-manager/_mixins/agentic/fence/default.nix](../../../../home-manager/_mixins/agentic/fence/default.nix) |
| Freshener job, with auto-merge off | [.github/freshener/roamgate.sh](../../../../.github/freshener/roamgate.sh) |

The server runs outside Fence as the `roamgate.service` systemd user service, on `127.0.0.1:8787`, with `Restart=on-failure`. It starts after `herdr.service` and connects to the Herdr sockets directly. It is not the Roamgate Herdr plugin, which downloads a prebuilt binary, so do not run `herdr plugin install` or `herdr plugin link` for it. It runs from source on Bun, so the self-updater cannot replace it, and `ROAMGATE_DISABLE_UPDATE_CHECK=1` turns off update checks (see [Browser settings](#browser-settings)). The unit does not set `NODE_ENV`, because `NODE_ENV=development` on a loopback bind turns login off.

The `roamgate-serve.service` user unit starts after `roamgate.service`, waits for `tailscaled` to log in, then runs `tailscale serve --bg --yes --https=10000 http://127.0.0.1:8787`. The user is the Tailscale operator, so the unit needs no root. The mapping persists in the tailscaled state, each start sets the same mapping again, and a stop of the unit removes it. Herdr Web keeps port 8443.

State is in `~/.config/roamgate/`: the env file `roamgate.env`, the generated login token, the session secret, settings, connection profiles, push keys, Ranger data, and uploads. Roamgate refuses a symlink in that path, so Home Manager links no file into it. Fence denies reads and writes of this directory and of the legacy `~/.config/herdr-gui/`, because the session secret signs a cookie that opens every route of the server.

## Login

Each activation decrypts two keys with `sops` and the user's age key, and writes `~/.config/roamgate/roamgate.env` with mode 0600. sops-nix does not render the values, because Fence keeps `~/.config/sops-nix` readable.

| File | Key | Variable | Value |
| --- | --- | --- | --- |
| `secrets/herdr.yaml` | `ROAMGATE_PIN` | `ROAMGATE_PIN` | The login PIN for skrye and zannah. 6 to 12 ASCII digits. |
| `secrets/ai.yaml` | `OPENCODE_ZEN_API_KEY` | `OPENCODE_API_KEY` | The OpenCode API key of the OpenCode Go subscription, for [Ranger](#ranger). |

If the age key is missing, a file or a key is missing, decryption fails, a value is empty, or the PIN is not 6 to 12 digits, activation prints a `roamgateEnv` warning with the reason and leaves the old file. One failed key keeps both old values, so a missing API key also stops a PIN change. Roamgate exits at start with a PIN outside that rule. Activation also warns when the file is still missing. Without the file the pre-start check fails and logs `missing ~/.config/roamgate/roamgate.env`, so the server never runs without the PIN.

No password is set, so Roamgate generates a 64-character login token in `~/.config/roamgate/auth-token` at its first start. The PIN login is an addition to the token login, not a replacement. Keep the token for recovery: read it from that file outside Fence, and log in with it as the password.

Log in with the PIN. The login cookie `herdr_auth` lasts 30 days, and logout does not revoke a copied cookie. To rotate the PIN, change it in `secrets/herdr.yaml`, run `just switch-home`, then run `systemctl --user restart roamgate`.

A PIN is much weaker than a password or the token, and Roamgate itself warns to use it only behind a trusted private network or VPN. Keep Funnel off. All proxied clients arrive from `127.0.0.1`, so they share one login rate limit. Five failed PIN logins from any tailnet device lock PIN login for five minutes. Ten failed PIN logins in a row lock PIN login for one hour for every client. A PIN lock does not lock the token login.

## Shared hostname and cookies

Roamgate, Herdr Web on port 8443, and the Caddy apps on port 443 use the same hostname. Browsers ignore the port for cookies, so each app receives the cookies of the others. The cookie names differ, so the apps do not overwrite each other. All `*.drongo-gamma.ts.net` hosts are one site, so a script on any tailnet origin can open the Roamgate WebSocket with the cookie. Keep untrusted HTML off the tailnet origins.

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

## What to compare with Herdr Web

- Type in a pane while Herdr Web has the same tab open. Both clients share pane focus and terminal size.
- Resize the browser and check the terminal size in the other client and in the TUI.
- Install the app on the phone over the tailnet URL, then check web push.
- Open a diff and the file explorer on a repository.
- Copy from a pane with OSC 52.
- Compare agent status and session history for each agent.

## Upgrades

The freshener opens a pull request for each upstream `vX.Y.Z` release and does not enable auto-merge. Review the upstream diff before you merge. The release rate is high, so expect several pull requests each week. The build fails when a release changes the hook default lines that the package patches, or when the server imports a package outside the pruned `node_modules`. Add that package to the `prune-node-modules.ts` call in the package.

Upstream declares Bun 1.4.3. The flake has Bun 1.4.2, and the build and a short run pass with it.

## Set up

1. Put the PIN in `secrets/herdr.yaml` as `ROAMGATE_PIN` with `sops`.
2. Make sure that `secrets/ai.yaml` has `OPENCODE_ZEN_API_KEY`, the key of the OpenCode Go subscription.
3. Run `just switch-home` on skrye and on zannah.
4. Open the host URL and log in with the PIN.
5. Add the app to the Home Screen on the phone, so that web push works.
6. In each browser and in the phone app, open the settings, then the **Behavior** tab. Turn off **Automatic update checks**.
7. On the same tab, turn on **Task notifications** and allow notifications when the browser asks. Wait until the status shows **On · Background push**.
