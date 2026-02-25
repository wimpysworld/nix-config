# Fingerprint Unlock

Enables fprintd and configures PAM so fingerprint authentication works only
through hyprlock's native D-Bus integration. Login, sudo, and polkit require
a passphrase.

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

Two modules collaborate:

**NixOS mixin** (`nixos/_mixins/hardware/fprint/default.nix`)

- Enables `services.fprintd`
- Sets `fprintAuth = false` on greetd, login, hyprlock, sudo, and polkit-1
  PAM services. NixOS defaults `fprintAuth = true` on every PAM service when
  fprintd is enabled; these overrides restrict fingerprint to screen unlock
- Runs a `fprintd-resume` systemd unit that restarts fprintd after
  suspend/resume to clear stale device handles

**Hyprlock module** (`home-manager/.../hyprlock/default.nix`)

- Adds an `auth.fingerprint` block when the host carries the `"fprintd"` tag.
  Hyprlock v0.5.0+ opens password and fingerprint channels in parallel via
  D-Bus, so either method unlocks without waiting
- Displays a `$FPRINTPROMPT` label (renders empty on non-fprintd hosts)
- Swaps the input-field glyph from a key icon to a fingerprint icon

The PAM lockdown on hyprlock is required. Without it, both hyprlock's D-Bus
path and PAM's `pam_fprintd.so` attempt to claim the sensor simultaneously,
causing a "device already open" error on one or both.

## Rollback

Remove `"fprintd"` from the host's tags and rebuild. Both modules gate on the
tag, so they become inert. Enrolled fingerprints remain on disk but are unused.

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
