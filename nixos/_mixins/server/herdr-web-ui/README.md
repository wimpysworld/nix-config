# Herdr Web

[Herdr Web](https://github.com/devswha/herdr-web-ui) shows every Herdr workspace, tab, and pane in a browser or a phone app, as a chat and a live terminal. It can type into every pane and read any file of the user. skrye and zannah run it, and Tailscale Serve publishes it on the tailnet. No other host runs it.

## URLs

| Host | URL |
| --- | --- |
| skrye | `https://skrye.drongo-gamma.ts.net:8443` |
| zannah | `https://zannah.drongo-gamma.ts.net:8443` |

Each host is its own origin, so pair and install each app separately. The phone must have Tailscale connected each time it opens the app. Funnel stays off, so the app is not on the internet.

## Parts

| Part | Source |
| --- | --- |
| Package: built from source, with a fixed-output `node_modules` | [pkgs/herdr-web-ui/default.nix](../../../../pkgs/herdr-web-ui/default.nix) |
| User service, sops decryption, and the env file | [home-manager/_mixins/terminal/herdr.nix](../../../../home-manager/_mixins/terminal/herdr.nix) |
| Tailscale Serve unit on port 8443 | [default.nix](default.nix) |
| Fence read and write denial | [home-manager/_mixins/agentic/fence/default.nix](../../../../home-manager/_mixins/agentic/fence/default.nix) |
| Freshener job, with auto-merge off | [.github/freshener/herdr-web-ui.sh](../../../../.github/freshener/herdr-web-ui.sh) |

The server runs outside Fence as the `herdr-web-ui.service` systemd user service, on `127.0.0.1:7317`, with `Restart=on-failure`. It is not a Herdr plugin, so Herdr does not start a second copy. It runs without the upstream supervisor, so the self-updater is off and the Settings update control does nothing. Telemetry is off with `HERDR_WEB_TELEMETRY=0`.

The `herdr-web-ui-serve.service` system unit runs `tailscale serve --bg --yes --https=8443 http://127.0.0.1:7317` after `tailscaled` is up. The mapping persists in the tailscaled state, and a stop of the unit removes it. Do not put Caddy in front of the server. Tailscale Serve sets and strips the `Tailscale-User-Login` header, but Caddy passes a forged header through, and the server trusts that header from a loopback client.

State is in `~/.config/herdr-web-ui/`: paired devices, push keys, bridge tokens, and the env file `service.env`. Pasted files go to `~/.config/herdr-web-ui/paste/`. Fence denies reads and writes of the whole directory, because a bridge token opens every route of the server, including reads of any file.

## Token and owner login

Each activation decrypts two keys from `secrets/herdr.yaml` with `sops` and the user's age key, and writes `~/.config/herdr-web-ui/service.env` with mode 0600. sops-nix does not render the values, because Fence keeps `~/.config/sops-nix` readable.

| Key | Value |
| --- | --- |
| `HERDR_WEB_TOKEN_SKRYE`, `HERDR_WEB_TOKEN_ZANNAH` | The access token for the host, as `HERDR_WEB_TOKEN`. A long random string, for example from `openssl rand -base64 32`. |
| `HERDR_WEB_TAILSCALE_OWNER` | The Tailscale login of the owner, `martin@wimpress.org`. |

If decryption fails or a value has a character outside `A-Za-z0-9._~+/=:@-`, activation prints a warning and leaves the old file. Without the file the service does not start, so the server never runs without a token.

With a token set, the server refuses every request that has no token cookie, Bearer token, or paired-device cookie, from loopback too. The token check comes before the `Tailscale-User-Login` check in `server/access.ts`, so the owner login alone does not let a device in. The NixOS hosts have the tag `tag:nixos` and no owner login, so `HERDR_WEB_TAILSCALE_OWNER` names the owner for the server.

## Pairing

1. Put the token for each host and the owner login in `secrets/herdr.yaml` with `sops`.
2. Run `just switch-host` on skrye and on zannah.
3. Run `just switch-home` on each host.
4. On a trusted device, open the host URL and sign in with the token for that host.
5. In Settings, Devices, create a pairing code. Enter the six-digit code on the phone within 10 minutes. Choose `watch` for a device that only observes.
6. Add the app to the Home Screen on the phone, so that web push works.

Device cookies last one year. Revoke a lost device in Settings, Devices. To rotate a token, change it in `secrets/herdr.yaml`, run `just switch-home`, then run `systemctl --user restart herdr-web-ui`.

## Upgrades

The freshener opens a pull request for each upstream `vX.Y.Z` release and does not enable auto-merge. Review the upstream diff before you merge. The install check fails when the server imports a package outside the pruned `node_modules`. Add that package to the `prune-node-modules.ts` call in the package.

## Herdr Telegram Agents

[Herdr Telegram Agents](https://github.com/permgps/herdr-telegram-agents) mirrors each Herdr agent into a topic of a Telegram forum group. The bot can type into every agent pane, and Telegram can read all posts, because bot chats have no end-to-end encryption. Only skrye and zannah enable it, with one bot and one group for each host. A second poller on the same token makes the daemon exit.

| Part | Source |
| --- | --- |
| Package: `herdr-tg` built from source, and the Herdr plugin tree | [pkgs/herdr-telegram-agents/default.nix](../../../../pkgs/herdr-telegram-agents/default.nix) |
| Plugin link, sops decryption, and the `config.json` write | [home-manager/_mixins/terminal/herdr.nix](../../../../home-manager/_mixins/terminal/herdr.nix) |
| Fence read and write denial | [home-manager/_mixins/agentic/fence/default.nix](../../../../home-manager/_mixins/agentic/fence/default.nix) |
| Freshener job, with auto-merge off | [.github/freshener/herdr-telegram-agents.sh](../../../../.github/freshener/herdr-telegram-agents.sh) |

Herdr starts the daemon outside Fence after session restore. The daemon reads the bot token only from `~/.config/herdr/plugins/config/permgps.telegram-agents/config.json` and rewrites that file itself. Each activation decrypts the host's keys from `secrets/herdr.yaml` with `sops` and the user's age key, then writes the whole file atomically with mode 0600. sops-nix does not render the values, because Fence keeps `~/.config/sops-nix` readable. It also merges the declared options into `options.json`. The state directory is `~/.local/state/herdr/plugins/permgps.telegram-agents/`. Fence denies reads and writes of both directories.

The plugin has no option to turn off Share or the update action. Do not use Share, and leave Threaded Mode off in BotFather, because Share needs Threaded Mode. The update action refuses a plugin linked from the Nix store, so upgrades come from the freshener only.

### Set up a host

Activation writes the whole `config.json`, so the plugin needs no setup popup. It reads these keys from `secrets/herdr.yaml`:

| Key | Value |
| --- | --- |
| `TELEGRAM_BOT_SKRYE`, `TELEGRAM_BOT_ZANNAH` | The bot token for the host, from @BotFather. |
| `TELEGRAM_CHAT_ID_SKRYE`, `TELEGRAM_CHAT_ID_ZANNAH` | The supergroup ID for the host, as a string, for example `"-1001234567890"`. |
| `TELEGRAM_OPERATOR_IDS` | The numeric Telegram user IDs that can drive the agents, as one comma-separated string. |

`herdrTelegramAgentsHosts` in `herdr.nix` names the keys for each host and sets the bot username. The observer list and the log level are also in `herdr.nix`. Activation replaces every value in `config.json`, so a change from setup or `/observers` lasts only until the next switch.

`options` in `herdrTelegramAgentsSettings` sets these values in `options.json` on every activation, so a change from `/options` to one of them lasts only until the next switch:

- `privacy.redact`: `true`, to mask secrets in every post.
- `topics.delete_after_days`: `"1"`, to delete the closed topic of an exited agent after one day.

Every value except a bool must be a JSON string, or the daemon ignores it. A topic icon (`icons.*`) must be in Telegram's free topic-icon pack, and two statuses cannot share one icon. The daemon reads `options.json` only at start, so run `herdr-tg-agent restart` after a switch to load the options.

1. Turn on Telegram 2-Step Verification for your account: **Settings > Privacy and Security > Two-Step Verification**.
2. In @BotFather, send `/newbot` and create one bot for the host. Put its username in `herdrTelegramAgentsHosts` and its token in `secrets/herdr.yaml` with `sops`.
3. Create a private group, open its settings, and turn on **Topics**. Telegram converts the group to a supergroup. Add only your own account.
4. Add the bot to the group as an admin with **Manage topics**, **Delete messages**, and **Pin messages**. Promote it from your own account, not as an anonymous admin.
5. Put the group ID and your user ID in `secrets/herdr.yaml` with `sops`. Telegram Web shows the group ID in the address bar when the group is open, at `https://web.telegram.org/a/#-100...`. A message to @userinfobot returns your user ID.
6. Run `just switch-home` on the host. If decryption fails or a value is not valid, activation prints a warning and leaves `config.json` unchanged.
7. Run `herdr-tg-agent start` on the host. After a plugin update or a change to `config.json`, run `herdr-tg-agent restart` instead.

Herdr starts the daemon only when the Herdr server starts, so a switch does not start or restart it. The daemon reads `config.json` only at start. `herdr-tg-agent start|stop|restart|status` runs the plugin action, waits up to 15 seconds for it to finish, prints its output, and exits with its exit code. Only skrye and zannah install the command.
