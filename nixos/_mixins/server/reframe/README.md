# ReFrame remote desktop

ReFrame provides browser-based remote access to the four tagged Hyprland hosts. The supported entry point is `https://<host>.<tailnet>/novnc` from a Tailscale peer.

> [!WARNING]
> This stack has not been deployed or tested on a live host. Complete the per-host acceptance checklist before relying on it. Keep a local or out-of-band recovery path throughout the rollout.

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

The `reframe` tag enables the NixOS ReFrame, websockify, and Caddy configuration. Display connectors and geometry come from `lib/registry-systems.toml`. Each target uses DRM `card1`.

| Host | Captured connector | Registry layout | ReFrame desktop and primary offset |
| --- | --- | --- | --- |
| `bane` | `eDP-1` | `eDP-1` at `2560x1600+0+0`, scale `1.25` | `2560x1600`, offset `0,0` |
| `ravi` | `eDP-1` | `eDP-1` at `2880x1920+0+0`, scale `1.5` | `2880x1920`, offset `0,0` |
| `skrye` | `DP-1` | `DP-1` at `2560x2880+0+0`; `DP-4` at `2560x2880+2560+0` | `5120x2880`, offset `0,0` |
| `zannah` | `DP-1` | `DP-1` at `3440x1440+0+1280`; `HDMI-A-1` at `2560x1600+1920+0`, scale `1.25` | `3968x2720`, offset `0,1280` |

Tagged multi-monitor hosts use their full registry layout at the greetd login screen. Single-monitor hosts use Cage's single-output layout. ReFrame starts as a system service, so the design supports capture before login and after Hyprland starts. This behaviour still needs live verification on every target.

## Capture and input

- The `uinput` kernel module provides remote keyboard and pointer input.
- `cursor=true` includes the pointer in the captured image.
- `resize=true` lets the VNC client request a size change.
- `wakeup=true` wakes a blanked display when input arrives.
- `damage=cpu` uses CPU damage tracking.
- `fps=30` sets the capture target to 30 frames per second.

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

Text clipboard sync is deferred. Tagged desktop users do not join the `reframe` group, and the configured package omits its XDG autostart file. No `reframe-session` process starts in a graphical session.

This keeps user sessions outside the group that can connect to `/run/reframe-session/*.sock`. It also prevents a connected VNC client from reading or replacing local clipboard text. noVNC users cannot copy text between the remote desktop and their local device.

Enable clipboard sync only after a deployed tagged host passes a logged-in Hyprland test. Add only its desktop user to `reframe`, restore the packaged autostart file, rebuild, and log out and back in. Test distinct benign text in both directions. Confirm that an untagged host has no group membership, autostart entry, or session process.

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
- [ ] The greetd screen is visible before login with the registry connector layout and pointer mapping.
- [ ] Capture continues after login to Hyprland with the same geometry.
- [ ] Keyboard and pointer input work through `uinput` without affecting local input.
- [ ] The remote cursor is visible and tracks the pointer.
- [ ] Client resizing works and preserves pointer mapping.
- [ ] Input wakes the display after blanking.
- [ ] CPU damage tracking remains stable during screen motion.
- [ ] Capture reaches the configured 30 FPS target during screen motion.
- [ ] Clipboard text does not cross the session boundary, no `reframe-session` process runs, and the desktop user is not in the `reframe` group.

Record results per host. These checks have not yet run.

## Rollback

Rollback must restore both generation types. Roll back NixOS first so websockify releases port `5900`, then roll back Home Manager so the previous user service can bind it.

```bash
sudo nixos-rebuild switch --rollback
home-manager switch --rollback
```

Confirm both commands selected the generation recorded before deployment. If the host is not reachable, boot the previous NixOS generation from the boot loader, log in locally, then run the Home Manager rollback. Do not start the old user service while the new websockify service still owns port `5900`.
