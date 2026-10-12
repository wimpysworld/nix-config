# Herdr

This directory documents the Herdr server, the Context Bar and Model Display plugins, the Herdr Telegram Agents plugin, and [Roamgate](roamgate.md), the browser and phone client.

## Herdr server

Every non-ISO host runs the Herdr server as a service from [home-manager/_mixins/terminal/herdr.nix](../herdr.nix). Linux uses the `herdr.service` systemd user service, and momin uses the `org.nix-community.home.herdr` launchd agent. Both run `~/.nix-profile/bin/herdr server`, the profile path and not a store path, so a Herdr update does not change the unit or the plist.

- On NixOS, [nixos/_mixins/users/default.nix](../../../../nixos/_mixins/users/default.nix) sets `linger`, so the user manager and the server start at boot, before any login. On momin the server starts at login. Lima and WSL hosts start it with their user manager.
- The unit sets `X-SwitchMethod=keep-old`, so `just switch-home` never restarts a running server or its panes. It sets `Restart=on-failure`, so a crash restarts it, but `herdr server stop` leaves it stopped.
- On NixOS the unit sets `SSH_AUTH_SOCK` to the `ssh-agent.service` socket. It sets no display variables. On a workstation, a fish shell in a Herdr pane copies `WAYLAND_DISPLAY`, `DISPLAY`, and the other compositor variables from `systemctl --user show-environment` when it has no display.
- If a server already owns the socket, the service skips its start instead of failing in a loop.

To load a new Herdr version, which ends every pane process, run `systemctl --user restart herdr` on Linux, or `launchctl kickstart -k gui/$(id -u)/org.nix-community.home.herdr` on momin.

The first switch that adds the service finds a server started by hand, so the service does not start. To hand over, detach the clients, run `herdr server stop`, then run `systemctl --user start herdr` on Linux, or `launchctl kickstart gui/$(id -u)/org.nix-community.home.herdr` on momin. On NixOS, `just switch-host` sets linger, and the next boot also starts the service.

## Context Bar

[Context Bar](https://github.com/pdalinis/herdr-ctx-bar) shows a thin bar under each Claude Code, Codex, Pi, and Hermes Agent entry in the Agents sidebar. The bar shows how much of the context window the session uses. It is green below 50%, yellow from 50% to 79%, and red at 80% and above. Every non-ISO host links it.

| Part | Source |
| --- | --- |
| Package: the plugin tree, with the manifest pinned to the store Python | [pkgs/herdr-ctx-bar/default.nix](../../../../pkgs/herdr-ctx-bar/default.nix) |
| Plugin link, daemon restart, and the sidebar rows | [home-manager/_mixins/terminal/herdr.nix](../herdr.nix) |
| Fence read and write denial of the state directory | [home-manager/_mixins/agentic/fence/default.nix](../../../../home-manager/_mixins/agentic/fence/default.nix) |
| Freshener job, with auto-merge off | [.github/freshener/herdr-ctx-bar.sh](../../../../.github/freshener/herdr-ctx-bar.sh) |

The plugin runs one Python daemon for each Herdr server, outside Fence. The daemon reads the tail of each agent transcript under `~/.claude/projects`, `~/.codex/sessions`, and `~/.pi/agent/sessions`, and Hermes `state.db`, and reports only the bar to Herdr. It makes no network request. The agent-state hooks that the agent modules install give Herdr the session ID, so the daemon reads the correct transcript.

Upstream asks for two first-use steps, and neither is needed here:

- The `setup` action appends the sidebar rows to `config.toml`. `settings` in `herdr.nix` declares the rows instead, so `setup` finds them and changes nothing.
- `herdr integration install` installs the agent-state hooks. The Claude Code, Codex, OpenCode, and Pi modules install them from `pkgs/herdr-integrations`.

Herdr runs the plugin startup hook only when the server starts. Each activation invokes the `restart` action after the config reload, so a running server starts the daemon from the new store path. With no server running, the step does nothing. To check the daemon, run `herdr plugin action invoke status --plugin herdr-ctx-bar`, then `herdr plugin log list --plugin herdr-ctx-bar`.

The state directory `~/.local/state/herdr/plugins/herdr-ctx-bar/` holds the daemon lock, which records the PID that `restart` signals. Fence denies reads and writes of it, so a sandboxed process cannot plant a PID.

## Model Display

[Model Display](https://github.com/pdalinis/herdr-disp-model) shows the model and reasoning effort of each Claude Code, Codex, and Pi session in the Agents sidebar. Each hook reports `$model` and `$effort` tokens. The first Agents row ends with the plain `agent` name, and the second row shows the model and effort, as `claude-opus-5-5 · high`. Every non-ISO host links it. The sidebar is 36 columns wide, not the default 26, so the rows fit.

| Part | Source |
| --- | --- |
| Package: the plugin tree at a pinned commit, with the manifest pinned to the store Python | [pkgs/herdr-disp-model/default.nix](../../../../pkgs/herdr-disp-model/default.nix) |
| Plugin link and the sidebar width | [home-manager/_mixins/terminal/herdr.nix](../herdr.nix) |
| Claude Code hooks | [home-manager/_mixins/agentic/claude-code/default.nix](../../agentic/claude-code/default.nix) |
| Codex hooks | [home-manager/_mixins/agentic/codex/default.nix](../../agentic/codex/default.nix) |
| Pi extension, Linux only, like the Herdr Pi extension | [home-manager/_mixins/agentic/pi/default.nix](../../agentic/pi/default.nix) |
| Freshener job, with auto-merge off | [.github/freshener/herdr-disp-model.sh](../../../../.github/freshener/herdr-disp-model.sh) |

The plugin has no daemon and no state. The hooks run inside each agent session, and inside Fence when the agent is fenced. Each hook reads the model and effort from the hook input, and the Codex hook can also read the tail of the session transcript and `models_cache.json`. It sends them to Herdr with `herdr pane report-metadata`. It makes no network request.

Upstream asks for a `setup-all` action, which writes the hooks into `~/.claude/settings.json` and `~/.codex/hooks.json` and copies the Pi and Hermes adapters. The agent modules declare the same hooks and the Pi extension instead, so do not run `setup-all` or `remove-all`. Hermes Agent runs here as a system service, not in a Herdr pane, so it gets no adapter.

Upstream also replaces the `agent` name with a `claude - claude-opus-5-5 - high` label. The package patches out `--display-agent` and `--clear-display-agent`, so `agent` shows the plain name and `$model` and `$effort` are the tokens to use in sidebar rows. A label from an unpatched hook stays until the agent's next model report from the new hook, or until the agent exits or the pane closes.

## Herdr Telegram Agents

[Herdr Telegram Agents](https://github.com/permgps/herdr-telegram-agents) mirrors each Herdr agent into a topic of a Telegram forum group. The bot can type into every agent pane, and Telegram can read all posts, because bot chats have no end-to-end encryption. Only skrye and zannah enable it, with one bot and one group for each host. A second poller on the same token makes the daemon exit.

| Part | Source |
| --- | --- |
| Package: `herdr-tg` built from source, and the Herdr plugin tree | [pkgs/herdr-telegram-agents/default.nix](../../../../pkgs/herdr-telegram-agents/default.nix) |
| Plugin link, sops decryption, and the `config.json` write | [home-manager/_mixins/terminal/herdr.nix](../herdr.nix) |
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

Herdr starts the daemon only when the Herdr server starts. After a reboot the daemon starts by itself, because the Herdr server starts at boot. A switch leaves the running server in place, so it does not start or restart the daemon; run `herdr-tg-agent start` or `herdr-tg-agent restart` after a switch. The daemon reads `config.json` only at start. `herdr-tg-agent start|stop|restart|status` runs the plugin action, waits up to 15 seconds for it to finish, prints its output, and exits with its exit code. Only skrye and zannah install the command.
