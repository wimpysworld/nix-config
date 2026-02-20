# wayvnc - Browser-Based Remote Desktop

Browser-based remote desktop access to Hyprland workstations over Tailscale, using wayvnc, noVNC, and Caddy.

Navigate to `https://<host>.<tailnet>/novnc` from any Tailscale peer. The page auto-connects and prompts for credentials.

## Security

**This setup is safe only within a Tailscale network.**

Authentication uses VeNCrypt Plain (type 256), which sends the username and password in cleartext over the VNC protocol. All traffic is encrypted by Tailscale's WireGuard tunnel, so credentials never traverse an unencrypted link. Do not expose these services to the public internet.

## Architecture

```
Browser (Tailscale peer)
  |
  | HTTPS over WireGuard
  v
Caddy (NixOS system service)
  |-- /novnc/vnc.html, JS, CSS  -->  file_server (pkgs.novnc)
  |-- /novnc/websockify           -->  reverse_proxy localhost:5900
  v
wayvnc (Home Manager user service)
  listening on 127.0.0.1:5900 with --websocket
```

wayvnc speaks WebSocket natively via `--websocket`, so Caddy proxies directly to it. No websockify bridge is needed.

Caddy serves the noVNC static assets from the Nix store (`pkgs.novnc`) and reverse-proxies the WebSocket path to wayvnc. A redirect on `/novnc` sets `path=websockify&autoconnect=true` so the client connects immediately.

## Gating

Enabled when both conditions are met:

1. The host has the `"wayvnc"` tag in `lib/registry-systems.nix` (currently vader and phasma).
2. A Wayland compositor (Hyprland or Wayfire) is enabled.

The Caddy noVNC block additionally requires Tailscale to be active.

## Files

| File | Layer | Purpose |
|------|-------|---------|
| `home-manager/_mixins/services/wayvnc/default.nix` | Home Manager | sops template, wayvnc service, ExecStart override |
| `nixos/_mixins/server/caddy/default.nix` | NixOS | noVNC static assets + WebSocket reverse proxy (`lib.mkMerge` block) |
| `nixos/_mixins/server/novnc/default.nix` | NixOS | Placeholder (websockify removed, kept for auto-import) |
| `secrets/wayvnc.yaml` | sops | Encrypted VNC password |

## Secrets

The VNC password is stored in sops and rendered into a wayvnc config file at activation time via a sops template.

```bash
sops secrets/wayvnc.yaml
# Add: wayvnc_password: YOUR_VNC_PASSWORD
```

The sops template renders to `$XDG_CONFIG_HOME/sops-nix/secrets/wayvnc-config`, which wayvnc reads via `--config`. This bypasses the Home Manager-generated config in the Nix store (which cannot contain secrets).

The systemd unit declares `After` and `Wants` on `sops-nix.service` to ensure secrets are decrypted before wayvnc starts.

## CLI flags

Flags set via `ExecStart` override (the Home Manager module does not expose CLI options):

| Flag | Purpose |
|------|---------|
| `--config` | Points to sops-rendered config with the VNC password |
| `--websocket` | Native WebSocket support, no bridge needed |
| `--render-cursor` | Composites cursor into framebuffer for reliable visibility |
| `--max-fps=30` | Reasonable frame rate for remote desktop |
| `--output=<primary>` | Pins to the primary display from `host.display.primaryOutput` |

Flags intentionally omitted:

- `--gpu` - causes screencopy protocol errors that drop connections (wayvnc issue #327)
- `--disable-resizing` - omitted to allow noVNC to negotiate resolution

## Authentication details

The config file sets:

```ini
enable_auth=true
relax_encryption=true
username=<noughty.user.name>
password=<from sops>
```

`relax_encryption=true` is required because VeNCrypt Plain has no TLS or RSA layer. Without it, wayvnc rejects the configuration.

### Why not RSA-AES authentication?

wayvnc (via neatvnc) offers security types 5 (RA2) and 129 (RA2_256). noVNC 1.6.0 supports RA2ne (type 6). These are incompatible - the VNC handshake fails because neither side advertises a type the other accepts. VeNCrypt Plain is the strongest mutually supported option.

## Runtime commands

Switch the captured display without restarting wayvnc:

```bash
wayvncctl output-set <output-name>
```

Check service status:

```bash
systemctl --user status wayvnc.service
journalctl --user -u wayvnc.service -f
```
