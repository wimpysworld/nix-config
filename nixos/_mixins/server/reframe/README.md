# ReFrame remote desktop

ReFrame provides browser-based remote access to the four tagged Hyprland hosts. The supported entry point is `https://<host>.<tailnet>/novnc` from a Tailscale peer.

> [!WARNING]
> This stack is deployed and verified on `zannah`. Complete the per-host acceptance checklist on the remaining hosts before relying on it there. Keep a local or out-of-band recovery path throughout the rollout.

## Architecture

```text
Browser on the Tailnet
  -> HTTPS to Caddy
  -> /novnc static client and WebSocket proxy
  -> websockify on 127.0.0.1:5900
  -> ReFrame VNC server on 127.0.0.1:5933
  -> DRM capture and uinput
```

Caddy accepts requests only from the Tailscale IPv4 and IPv6 address ranges. It serves noVNC from the Nix store and proxies `/novnc/websockify` to websockify. Websockify is a restricted dynamic-user service and can connect only to localhost. ReFrame and websockify do not listen on a Tailnet, LAN, or public address.

Do not open TCP ports `5900` or `5933` in a firewall or publish them through another proxy. Caddy over the Tailnet is the only supported remote path.

## Host mappings

The `reframe` tag enables the NixOS ReFrame, websockify, and Caddy configuration. The captured connector comes from the primary display in `lib/registry-systems.toml`. Each target uses DRM `card1`.

| Host | Captured connector | ReFrame desktop |
| --- | --- | --- |
| `bane` | `eDP-1` | `2560x1600` |
| `ravi` | `eDP-1` | `2880x1920` |
| `skrye` | `DP-1` | `2560x2880` |
| `zannah` | `DP-1` | `3440x1440` |

ReFrame captures and maps input over the primary display alone. The compositor maps ReFrame's absolute pointer across the bounding box of the live output layout, and secondary monitors drop off DRM in deep standby, which is the normal state when connecting remotely. With the primary-only desktop the pointer mapping is exact in that state. While a secondary display is awake and in the layout, the pointer skews until it sleeps again.

ReFrame starts as a system service, so the design supports capture before login and after Hyprland starts. This behaviour still needs live verification on every target.

## Capture and input

- The `uinput` kernel module provides remote keyboard and pointer input.
- `cursor=true` includes the pointer in the captured image.
- `resize=true` lets the VNC client request a size change.
- `wakeup=true` wakes a blanked display when input arrives. `reframe-wakeup-key.patch` adds a KEY_WAKEUP press for lockers such as Veila that ignore pointer motion while displays are off, and retries the connector lookup while the display wakes. Filed upstream as [AlynxZhou/reframe#42](https://github.com/AlynxZhou/reframe/issues/42) and [PR #43](https://github.com/AlynxZhou/reframe/pull/43); drop the patch when a release includes it.
- `damage=gpu` compares frames on the GPU in 4 px tiles. The server has a persistent Mesa shader cache in `/var/cache/reframe-server`. Fall back to `damage=cpu` if tile artifacts appear.
- `fps=30` sets the capture target to 30 frames per second.
- `XKB_DEFAULT_LAYOUT` on `reframe-server@main` follows `host.keyboard.layout`, so VNC keysym translation matches the host layout instead of falling back to US.

## Password and runtime file

sops-nix renders the ReFrame configuration at activation time. `/etc/reframe` is `root:reframe` mode `0750`. `/etc/reframe/main.conf` is `reframe:root` mode `0440`. The server reads it as `reframe`, and the root streamer reads it through the `root` group without DAC override capabilities. Service arguments contain the config path, not the password. Do not print or copy this file during checks.

### Rotate the password

Run this only on a machine with an authorised age private key:

```bash
sops secrets/reframe.yaml
```

Change only the encrypted password value in the editor, save, then build and switch one target at a time. Activation rewrites the protected template and restarts the ReFrame units.

Never place the decrypted password in a command argument, shell history, Nix value, log, or documentation.

## Clipboard

Text clipboard sync is enabled on tagged workstations. The desktop user joins the `reframe` group, which grants access to `/run/reframe-session/*.sock`, and a Home Manager user service (`home-manager/_mixins/services/reframe-session/`) runs `reframe-session` bound to `graphical-session.target`. The configured package still omits its XDG autostart file so untagged hosts and other users never start a session process.

A connected, authenticated VNC client can read and replace the local clipboard text. This is accepted: the VNC password and the Tailnet boundary gate access. Group membership takes effect after logging out and back in.

## Operations

Open the client from a Tailnet peer:

```text
https://<host>.<tailnet>/novnc
```

The page connects automatically and prompts for the ReFrame VNC password.

Check service state:

```bash
systemctl status reframe-server@main.service \
  reframe-streamer@main.service \
  reframe-websockify.service \
  caddy.service
```

Follow service logs without reading the protected config:

```bash
journalctl -f \
  -u reframe-server@main.service \
  -u reframe-streamer@main.service \
  -u reframe-websockify.service \
  -u caddy.service
```

Check listeners and file metadata:

```bash
sudo ss -ltnp | rg '127\.0\.0\.1:(5900|5933)'
sudo stat -c '%U:%G %a %n' /etc/reframe /etc/reframe/main.conf
sudo -u reframe test -r /etc/reframe/main.conf
sudo -u root test -r /etc/reframe/main.conf
sudo -u nobody test ! -r /etc/reframe/main.conf
```

Expected metadata is `root:reframe 750` for the directory and `reframe:root 440` for `main.conf`.

## Migration and rollout

Do not deploy until an authorised age key can decrypt the source on the target without printing it. Confirm physical or out-of-band recovery before each switch.

Build both generations for every target first:

```bash
for host in bane ravi skrye zannah; do
  just build-host hostname="$host"
  just build-home username=martin hostname="$host"
done
```

Roll out in this order: `bane`, `ravi`, `skrye`, then `zannah`. The two single-monitor laptops come first. Complete every acceptance check on one host before starting the next.

On each target:

1. Record `nixos-rebuild list-generations` and `home-manager generations`.
2. Record the four service states and confirm the recovery path.
3. Run `just switch-home username=martin hostname=<host>` first. This removes the old user service and releases loopback port `5900`.
4. Run `just switch-host hostname=<host>` to activate ReFrame, websockify, Caddy, and the greetd layout.
5. Complete the runtime acceptance checklist.

The split switch creates a short period without remote desktop access. Run it locally or through an independent connection.

## Runtime acceptance checklist

Repeat this checklist on `bane`, `ravi`, `skrye`, and `zannah`. Stop and roll back the current host if local input, display, login, or network access regresses.

- [ ] All four system services are active and have no repeated restart or error messages.
- [ ] ReFrame listens only on `127.0.0.1:5933` and websockify only on `127.0.0.1:5900`.
- [ ] Direct access to ports `5900` and `5933` fails from another host.
- [ ] `https://<host>.<tailnet>/novnc` works from a Tailnet peer and is not reachable through a non-Tailnet route.
- [ ] Authentication accepts the configured password and rejects an incorrect password.
- [ ] `/etc/reframe` and `/etc/reframe/main.conf` have the expected owner, group, and mode.
- [ ] Service arguments and logs contain no password or decrypted config content.
- [ ] The greetd screen is visible before login with correct pointer mapping on the primary display.
- [ ] Capture continues after login to Hyprland with the same geometry.
- [ ] Keyboard and pointer input work through `uinput` without affecting local input, and keysym translation matches the host keyboard layout.
- [ ] The remote cursor is visible and tracks the pointer.
- [ ] Client resizing works and preserves pointer mapping.
- [ ] Input wakes the display after blanking, including from a locked session with displays powered off.
- [ ] GPU damage tracking remains stable during screen motion with no tile artifacts.
- [ ] Capture reaches the configured 30 FPS target during screen motion.
- [ ] Clipboard text syncs in both directions after the desktop user re-logs in with `reframe` group membership.

Record results per host. `zannah` passes wakeup, capture, input, layout, clipboard, and GPU damage checks; the remaining hosts have not yet run them.

## Rollback

Rollback must restore both generation types. Roll back NixOS first so websockify releases port `5900`, then roll back Home Manager so the previous user service can bind it.

```bash
sudo nixos-rebuild switch --rollback
home-manager switch --rollback
```

Confirm both commands selected the generation recorded before deployment. If the host is not reachable, boot the previous NixOS generation from the boot loader, log in locally, then run the Home Manager rollback. Do not start the old user service while the new websockify service still owns port `5900`.
