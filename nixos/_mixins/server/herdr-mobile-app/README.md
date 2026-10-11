# Herdr Mobile Relay

[Herdr Mobile Relay](https://github.com/0cv/herdr-mobile-relay) lets a phone monitor and control Herdr agents. Every Home Manager configuration that installs Herdr runs the relay. Caddy on skrye and zannah serves the phone app over the tailnet.

## Phone app URLs

| App | URL |
| --- | --- |
| skrye (default) | `https://skrye.drongo-gamma.ts.net:8443` |
| zannah | `https://zannah.drongo-gamma.ts.net:8443` |

[lib/herdr-mobile-app.nix](../../../../lib/herdr-mobile-app.nix) holds one base URL for each host, and the default app. Caddy and the setup links both read that file. To move an app, change its URL there.

The app has its own port because browser storage is per origin, and that storage holds every relay key and device credential. Caddy refuses clients from outside the tailnet. The phone must have Tailscale connected each time it opens the app.

## Parts

| Part | Source |
| --- | --- |
| Package: Go relay, committed `web/` app, and Herdr plugin tree | [pkgs/herdr-mobile-relay/default.nix](../../../../pkgs/herdr-mobile-relay/default.nix) |
| Plugin link, relay service, `herdr-mobile-relay-link` | [home-manager/_mixins/terminal/herdr.nix](../../../../home-manager/_mixins/terminal/herdr.nix) |
| Caddy site on port 8443 | [default.nix](default.nix) |
| Fence read denial | [home-manager/_mixins/agentic/fence/default.nix](../../../../home-manager/_mixins/agentic/fence/default.nix) |
| Freshener job, with auto-merge off | [.github/freshener/herdr-mobile-relay.sh](../../../../.github/freshener/herdr-mobile-relay.sh) |

The relay runs outside Fence, as the `herdr-mobile-relay.service` systemd user service on Linux and as the `com.herdr-mobile-relay.service` launchd agent on Darwin. It uses the community WebRTC gateways, with port mapping off and App Deployment off.

The relay key, device store, and push keys are in `~/.config/herdr-mobile-relay/`. The service sets `HERDR_RELAY_ENV` to `~/.config/herdr-mobile-relay/relay.env`, and the relay keeps its runtime files in that directory. Fence denies reads of the directory to fenced agents.

## Pairing

1. Run `just switch-host` on skrye and on zannah.
2. Run `just switch-home` on each host, then log in again so that new shells and the Herdr server get `HERDR_RELAY_ENV` and `HERDR_PHONE_APP_URL`.
3. On the phone, connect Tailscale, open each app URL, and add it to the Home Screen.
4. On each host, run `herdr-mobile-relay-link skrye` and scan the QR code in the skrye app.
5. On each host, run `herdr-mobile-relay-link zannah` and scan the QR code in the zannah app.
6. Clear the terminal after each scan, because the link holds the relay key.

`herdr-mobile-relay-link` with no argument prints the skrye link. The Herdr action **Herdr Mobile Relay: Show Phone Setup QR** also prints the skrye link. Each link pairs one more phone and revokes no device.

Do not rotate the relay key as a routine step. A rotation disconnects every paired app on that host until it pairs again. Revoke unused devices in the app, because device credentials do not expire.

## Upgrades

The freshener opens a pull request for each upstream release and does not enable auto-merge. Review the upstream diff, including the `web/` bundle, before you merge. A new `go` line in `go.mod` can need a newer `buildGo*Module`.

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
