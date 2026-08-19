# Fingerprint Unlock

Enables fprintd and configures Veila fingerprint unlock for Hyprland and
Wayfire. Veila authenticates fingerprints through fprintd's D-Bus API. Login,
sudo, and polkit require a password.

## Enabling

Add `"fprintd"` to a host's tags in `lib/registry-systems.toml`:

```toml
[bane]
kind = "computer"
platform = "x86_64-linux"
formFactor = "laptop"
tags = ["policy", "workspace", "dropbox", "fprintd"]
```

Rebuild and switch. No other files need changing - the mixin auto-imports via
`hardware/default.nix` and gates itself on the tag.

## Enrolment

```bash
sudo fprintd-enroll martin          # Enrol default finger
sudo fprintd-enroll -f right-index-finger martin  # Specific finger
fprintd-list martin                 # Verify
```

Enrolled prints persist in `/var/lib/fprint/martin/` across rebuilds.

## How It Works

Three modules collaborate:

**NixOS mixin** (`nixos/_mixins/hardware/fprint/default.nix`)

- Enables `services.fprintd`
- Sets `fprintAuth = false` on greetd, login, veila, sudo, and polkit-1
  PAM services. NixOS defaults `fprintAuth = true` on every PAM service when
  fprintd is enabled; these overrides restrict fingerprint to Veila's native
  integration
- Runs a `fprintd-resume` systemd unit that restarts fprintd after
  suspend/resume to clear stale device handles

**Veila NixOS module** (`nixos/_mixins/desktop/default.nix`)

- Enables `programs.veila` on non-ISO Linux workstations
- Provides the Veila package and the `veila` PAM service

**Veila Home Manager module**
(`home-manager/_mixins/desktop/compositor/components/veila/default.nix`)

- Writes `~/.config/veila/config.toml` and enables `[fingerprint]` only when
  the host carries the `"fprintd"` tag
- Uses Veila's native fprintd D-Bus integration for fingerprints and the
  `veila` PAM service for passwords
- Displays a fingerprint glyph on tagged hosts and a key glyph elsewhere
- Runs `veilad.service` and `veila-idle.service` under the selected compositor
  session target. The idle service locks after 300 seconds and before sleep
- Binds `veila lock` to <kbd>Super</kbd>+<kbd>L</kbd> and
  <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd> in Hyprland and Wayfire.
  `wayland-session lock` uses the same command

The PAM lockdown on `veila` is required. Without it, both Veila's D-Bus path
and PAM's `pam_fprintd.so` attempt to claim the sensor simultaneously, causing
a "device already open" error on one or both.

## Rollback

Remove `"fprintd"` from the host's tags and rebuild. The fprintd mixin becomes
inactive, and Veila disables `[fingerprint]`. Veila remains the screen locker,
and password unlock continues to work. Enrolled fingerprints remain on disk
but are unused.

## Troubleshooting

**Fingerprint fails after suspend/resume**

The `fprintd-resume` service handles this automatically. If it persists, check
the service status:

```bash
systemctl status fprintd-resume.service
journalctl -u fprintd.service --since "5 minutes ago"
```

**Enrolment appears to succeed but `fprintd-list` shows no fingers**

`fprintd-enroll` requires `sudo`. Without it, the polkit elevation prompt
appears but enrolment silently fails to persist.

**Sensor not detected**

Verify the hardware is recognised:

```bash
lsusb | rg -i fingerprint
```

Framework 16 uses a Goodix sensor supported by the standard `libfprint` driver.
Other hardware may need a TOD (Touch OEM Driver) - see `nixos/sidious/default.nix`
for an example.
