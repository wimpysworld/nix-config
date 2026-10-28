# Herdr

This directory documents the Herdr server, the Context Bar and Model Display plugins, and [Roamgate](roamgate.md), the browser and phone client.

## Herdr server

Every non-ISO host runs the Herdr server as a service from [home-manager/_mixins/terminal/herdr.nix](../herdr.nix). Linux uses the `herdr.service` systemd user service, and momin uses the `org.nix-community.home.herdr` launchd agent. Both run `~/.nix-profile/bin/herdr server`, the profile path and not a store path, so a Herdr update does not change the unit or the plist.

- On NixOS, [nixos/_mixins/users/default.nix](../../../../nixos/_mixins/users/default.nix) sets `linger`, so the user manager and the server start at boot, before any login. On momin the server starts at login. WSL hosts start it with their user manager.
- The unit sets `X-SwitchMethod=keep-old`, so `just switch-home` never restarts a running server or its panes. It sets `Restart=on-failure`, so a crash restarts it, but `herdr server stop` leaves it stopped.
- On NixOS the unit sets `SSH_AUTH_SOCK` to the `ssh-agent.service` socket. It sets no display variables. On a Linux workstation, a fish or bash shell in a Herdr pane always copies `WAYLAND_DISPLAY`, `DISPLAY`, and the other compositor variables from the user manager with `session-env`, so a stale value is replaced. Other shells copy them only when they have no display.
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
