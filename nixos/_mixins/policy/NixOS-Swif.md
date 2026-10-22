# Running Swif.ai on NixOS

Swif.ai is a mobile device management (MDM) service. Swif publishes a NixOS
module for its Linux agent. This repository uses that module, but not in the
way that the Swif documentation describes. The differences are in
[Architecture](#architecture) and [Generated policy files](#generated-policy-files).

## Prerequisites

- The host carries the `cg` tag in `lib/registry-systems.toml` and is
  `x86_64-linux`. Swif does not support NixOS on ARM.
- sops-nix is configured on the host.
- `secrets/policy.yaml` holds `swif-teamid`, `swif-firstname`,
  `swif-surname` and `swif-email`.
- IT added the CrowdStrike Falcon exclusions for the Swif binaries (see
  [Dependencies on IT](#dependencies-on-it)).

## Architecture

### Source pin

The vendor module is the flake input `swifteam`, a `flake = false` tarball from
`https://cdn.swifteam.com/st-agent-linux/v1.402.0/nixos/swifteam.tar.gz`.
The tarball holds no tenant values, so the public URL and its hash are safe in
this public repository. The module downloads four closed-source binaries with
`pkgs.fetchurl` and pinned hashes: `SwifInstaller`, the `swifteam` agent, the
`systemcheck` watchdog and the Swif desktop app.

### Gated vendor files

Five vendor files set configuration even when `services.swifteam.enable` is
false: `configuration.nix`, `desktop.nix`, `users/swifteam.nix`,
`security/pam_passwd.nix` and `security/login.defs.nix`. A plain import would
change every NixOS host. `swif.nix` reads the vendor import list and wraps
every file except `options.nix` in `lib.mkIf config.services.swifteam.enable`.
The vendor files stay unchanged. A new vendor file in a later version is also
wrapped.

The gate reads the platform from `config.noughty.host.platform`, not from
`pkgs`. The gated vendor files set `nixpkgs.config`, so a gate that reads
`pkgs` causes infinite recursion.

### Installer and secrets

The vendor installer bakes the team ID, first name, surname and email into a
script in the Nix store. The store is world-readable, and CI pushes closures to
FlakeHub Cache. This repository therefore leaves the four vendor identity
options empty and replaces the `ExecStart` of `swif-agent-installer.service`
with `swif-install`:

1. sops-nix decrypts the four keys to `/run/secrets/swif-*`, mode `0600`.
2. systemd `LoadCredential` copies them into the private credential directory
   of the unit.
3. `swif-install` checks that each credential exists and is not empty, then
   runs `SwifInstaller` with the same flags as the vendor script.
4. `swif-install` writes `/var/lib/swifteam/installed.flag` only after the
   installer succeeds. A failed run retries at the next boot.

`SwifInstaller` accepts only command-line flags, so the values are visible in
the process list while the one-shot installer runs.

### Units and state

| Unit | Purpose |
| --- | --- |
| `swif-agent-installer` | One-shot enrolment. Runs while the install flag is absent. |
| `swif-agent` | The agent. Starts only when the install flag exists. |
| `syscheck` | The watchdog. Starts only when the install flag exists. |
| `swif-device-lock` | Locks the console at boot when a PIN file exists. |

| Path | Content |
| --- | --- |
| `/var/lib/swifteam/` | Agent state and the install flag. |
| `/var/lib/swifteam/passwords/swifteam` | Password hash of the hidden admin user, written by the agent. |
| `/etc/swif/swifteam/` | Generated policy modules. Nothing imports them. |
| `/tmp/swif-device-lock-pin-code.txt` | Device lock PIN, written by the agent. |

## Obtaining the values

- Team ID: Swif console, Settings > Team.
- First name, surname and email: the identity of the device owner.

Edit them with `sops secrets/policy.yaml`. The sops key `swif-firstname` maps
to the vendor flag `-name`.

## Generated policy files

After enrolment, IT can assign policies to the device in the Swif console.
The agent does not apply them to the running system. It writes Nix modules
into `<nixRootPath>/swifteam/` and asks the user to rebuild. Swif expects the
user to import that directory from the flake.

This repository sets `nixRootPath = "/etc/swif"` and does not import the
generated files:

- A pure flake evaluation cannot read `/etc/swif`, so the files cannot reach
  any build, by design.
- The vendor default `/etc/nixos` is not used. A bare `nixos-rebuild` reads
  `/etc/nixos/flake.nix`, and Swif can require a `flake.nix` in its directory.
- `systemd.tmpfiles` creates `/etc/swif` as `root:root`, mode `0700`, so local
  users cannot read the policies.

Read the generated files after IT assigns policies, then decide with IT. Copy
accepted settings by hand into this repository's own modules after review.
Never commit the generated files to this public repository.

## Enrolling and verifying

Before the switch, on the host:

```bash
getent passwd 991    # Must print nothing.
getent group swifteam # Must print nothing.
```

Enrol:

```bash
just switch-host
journalctl -u swif-agent-installer -b # Expect "[swif-install] Done."
sudo reboot
```

The agent and watchdog check for the install flag only when they start, so
reboot after enrolment.

Verify:

```bash
swif-agent-check
systemctl status swif-agent syscheck
journalctl -u swif-agent -b
falcon-sensor-check
systemctl status kolide-launcher
```

`swif-agent-check` is read-only. It elevates itself with `sudo` and reports
enrolment, services, the hidden admin user, generated files, a pending device
lock and the state size. Then ask IT to confirm that the device is in Swif
Console > Device Inventory.

## Updating the agent

1. Change the version in the `swifteam` URL in `flake.nix`.
2. Run `just update swifteam`.
3. Diff the old and new vendor trees. Look for new files in `default.nix`,
   changed flags in `installer.nix`, and changes in `users/`, `security/` and
   any `mkForce`.
4. Run `just build-host`, then `just switch-host`, then reboot.

## Device lock and hidden admin user

- Device lock: when `/tmp/swif-device-lock-pin-code.txt` exists, the next boot
  switches to tty2 and asks for the PIN before the greeter starts.
- Hidden admin user: `swifteam`, UID 991, member of `wheel`. The agent writes
  its password hash. It has full `sudo` access.

## Accepted risks

- The hidden `swifteam` admin user has full `sudo` access. This is pending IT
  approval.
- The Swif units run as root without systemd hardening.
- The vendor replaces the PAM stack of `passwd`. `passwd` loses fingerprint
  authentication and can fail with "Module is unknown", because
  `pam_pwquality.so` has no store path. The user tests `passwd` after the
  switch.
- Any local user can create the device lock file in `/tmp` and lock the
  console at the next boot.
- The behaviour of the `syscheck` self-updater on NixOS is unknown. The
  binaries are store paths and cannot be replaced in place.
- The identity values are visible in the process list during the one-shot
  install.
- The vendor hashes are trust on first use. Swif publishes no signature.

## Dependencies on IT

- Falcon exclusions, before the switch:
  - `/nix/store/*-swifAgent/bin/swifteam`
  - `/nix/store/*-syscheck/bin/systemcheck`
  - `/nix/store/*-swif-installer/bin/SwifInstaller`
  - `/nix/store/*-SwifApp-171/opt/swifapp/SwifApp`
  - `osquery` from nixpkgs
  - The Live Terminal IOA exclusion from the Swif Falcon exclusions article.
- Agreement that generated policies are not applied yet.

## Removal

1. Ask IT to retire the device in the Swif console, or to run "Remove Swif
   Agent".
2. Remove the host from the gate in `swif.nix`, then run `just switch-host`.
3. Confirm first, because this cannot be undone, then delete the state:
   `sudo rm -rf /var/lib/swifteam /etc/swif /tmp/swif-device-lock-pin-code.txt`.
4. Tell IT, so that they can remove the Falcon exclusions.

## Troubleshooting

### Installer reports a missing or empty credential

Check that the four keys exist in `secrets/policy.yaml` and that
`/run/secrets/swif-*` exist. Then run
`sudo systemctl start swif-agent-installer`.

### Install flag exists but the agent is inactive

The agent checks the flag only at start. Reboot, or run
`sudo systemctl start swif-agent syscheck`.

### `passwd` fails with "Module is unknown"

The vendor PAM stack names `pam_pwquality.so` without a store path. Report it
to Swif. Do not patch the vendor file without approval.
