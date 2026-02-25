# Captive Portal

NixOS mixin module for automatic captive portal detection and browser launch.
Activates on laptops only (`host.is.laptop`).

When a captive portal is detected, the module disables DNS-over-TLS on the
wifi interface, sends a desktop notification, and launches `captive-browser`
with its own DNS bypass. After the user completes portal login, DoT is
restored automatically.

## Components

The module configures three things in `default.nix`:

### 1. `captive-browser`

A Go tool that starts a local SOCKS5 proxy resolving DNS via the
DHCP-provided DNS server, bypassing systemd-resolved entirely. Chromium
launches through this proxy in an isolated profile, so the portal's
DNS-intercepting behaviour works as intended.

This is the correct approach for portals that hijack DNS. System DNS
settings are irrelevant to the browser session because all resolution
happens through the SOCKS proxy using the network's own DNS server.

### 2. NetworkManager dispatcher script

A `connectivity-change` handler that runs as root when NetworkManager's
connectivity state changes:

- **PORTAL detected**: disables DoT on the wifi interface, sends a
  notification, launches `captive-browser` for each graphical session
- **FULL restored**: re-enables DoT (`opportunistic` mode)

The wifi interface is discovered dynamically via `nmcli` rather than
hardcoded, handling iwd naming conventions and multiple adapters.

### 3. Connectivity check endpoint

```nix
settings.connectivity = {
  uri = lib.mkDefault "http://nmcheck.gnome.org/check_network_status.txt";
  response = lib.mkDefault "NetworkManager is online";
};
```

The GNOME endpoint returns a known string on success. Any portal redirect
produces a different response, reliably triggering the `PORTAL` state.

This replaces `http://google.cn/generate_204`, which can be geo-blocked or
redirected on some networks. Both values use `lib.mkDefault` for per-host
overridability.

## Detection-to-login flow

1. Device connects to a captive portal network
2. systemd-resolved attempts DoT, fails, falls back to plain UDP
3. NetworkManager's connectivity check gets a redirect instead of the
   expected response string
4. NetworkManager sets `CONNECTIVITY_STATE = PORTAL`
5. Dispatcher fires, disables DoT via `resolvectl dnsovertls <iface> no`
6. Dispatcher sends a desktop notification
7. Dispatcher launches `captive-browser` (which uses its own SOCKS DNS
   bypass independently)
8. User completes portal login in the browser
9. NetworkManager re-checks connectivity, finds `FULL`
10. Dispatcher fires again, restores DoT via
    `resolvectl dnsovertls <iface> opportunistic`

## The DNS-over-TLS problem

Captive portals intercept HTTP traffic and DNS queries on unauthenticated
networks. DNS-over-TLS wraps DNS in a TLS connection that portals cannot
transparently intercept.

With `dnsovertls = "opportunistic"`, systemd-resolved falls back to plain
UDP when TLS fails. The initial fallback works, and the connectivity check
detects the portal. The problem is what happens next: resolved periodically
retries TLS. Each retry against the portal fails, causing brief DNS outages
while the timeout expires. These intermittent failures disrupt the browser
session and background connectivity re-checks.

The dispatcher solves this by calling `resolvectl dnsovertls <iface> no`
when `PORTAL` is detected, stopping TLS retries entirely. Plain UDP DNS
works reliably for the duration of the portal login. Once `FULL`
connectivity returns, the dispatcher restores `opportunistic` mode.

## Design decisions

### Why `captive-browser`

`captive-browser` runs its own SOCKS5 proxy that resolves DNS through the
DHCP-provided server. The browser session never touches systemd-resolved or
DoT. This is the correct approach because portal DNS interception is the
mechanism by which portals redirect users to their login pages.

Alternatives like `xdg-open http://neverssl.com` rely on system DNS, which
may be unreliable during portal login even with the DoT workaround.

### Why `systemd-run --user --machine=`

The dispatcher script runs as root. Launching a graphical application in the
user's session requires entering their systemd scope. The previous approach
used `runuser -l`, which starts a login shell and resets `PATH`,
`XDG_RUNTIME_DIR`, and other environment variables needed for Wayland.

`systemd-run --user --machine="$SESSION_USER@.host"` correctly enters the
user's systemd user instance, preserving the session environment. The
`--setenv` flags pass `DBUS_SESSION_BUS_ADDRESS` and `XDG_RUNTIME_DIR`
explicitly.

### Why `notify-desktop`

`notify-desktop` sends D-Bus desktop notifications without depending on
libnotify. It does not support notification actions, so the notification is
informational only, telling the user a portal was detected and the login
page is opening.

### Why the GNOME connectivity endpoint

The previous `http://google.cn/generate_204` endpoint can be geo-blocked,
redirected to consent pages, or filtered on certain networks. The GNOME
endpoint (`http://nmcheck.gnome.org/check_network_status.txt`) returns a
known string and is the canonical NetworkManager check URL.

## Per-host overrides

The wifi interface defaults to `wlan0` (iwd's convention for the first
wireless adapter). Override per-host for systems with different naming:

```nix
# nixos/myhost/default.nix
programs.captive-browser.interface = "wlan1";
```

The connectivity URI and response use `lib.mkDefault`, so per-host overrides
work without `lib.mkForce`:

```nix
# nixos/myhost/default.nix
networking.networkmanager.settings.connectivity = {
  uri = "http://connectivity-check.ubuntu.com/";
  response = "";
};
```

## Testing

Test when connected to a captive portal network.

### Check connectivity state

```bash
nmcli general status
```

### Watch dispatcher logs

```bash
journalctl -t captive-portal -f
```

### Check DoT setting per interface

```bash
resolvectl status
```

### Manually trigger connectivity check

```bash
nmcli networking connectivity check
```

### Manually simulate portal detection

The dispatcher script path follows the NixOS naming convention for
`dispatcherScripts`:

```bash
sudo CONNECTIVITY_STATE=PORTAL \
  /etc/NetworkManager/dispatcher.d/03userscript0001 "" connectivity-change
```

Set `CONNECTIVITY_STATE=FULL` to simulate connectivity restoration:

```bash
sudo CONNECTIVITY_STATE=FULL \
  /etc/NetworkManager/dispatcher.d/03userscript0001 "" connectivity-change
```
