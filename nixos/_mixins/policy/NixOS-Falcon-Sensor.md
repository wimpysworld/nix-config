# Bootstrapping CrowdStrike Falcon on NixOS

CrowdStrike Falcon provides security monitoring and intrusion detection.
NixOS is not officially supported by CrowdStrike, so the sensor must be
installed manually using pre-built binaries with patched ELF interpreters.
The kernel module backend does not work on NixOS; the BPF backend is used
instead.

This is unofficial and unsupported by CrowdStrike.

## Prerequisites

- The target host must carry the `policy` tag in
  `lib/registry-systems.toml`. The mixin gates itself with
  `noughtyLib.hostHasTag "policy"`.
- The host must have sops-nix configured with age keys at
  `/var/lib/private/sops/age/keys.txt`.
- The CrowdStrike CID must be encrypted in `secrets/policy.yaml` (see below).
- Access to the private GitHub repository containing Falcon sensor RPMs
  (configured via the `falcon-repo` sops secret; requires `gh` CLI
  authentication).

## Architecture

The declarative setup has three layers:

1. **NixOS module** (`modules/nixos/falcon-sensor.nix`): declares the systemd
   service (with CID/BPF configuration in ExecStartPre), tmpfiles rules, and
   a `logrotate` policy for the sensor's log files.
2. **Policy mixin** (`nixos/_mixins/policy/default.nix`): enables the module
   and wires up the CID via sops-nix for hosts carrying the `policy` tag.
3. **Bootstrap script** (`falcon-sensor-install`): automates the one-time
   extraction and patching of the sensor binaries into `/opt/CrowdStrike/`.

## Obtaining the Falcon sensor RPM

The Falcon sensor RPM is hosted in a private GitHub repository. The repository
name is stored as the `falcon-repo` sops secret and read by the
`falcon-sensor-install` script at runtime. The script handles downloading,
extracting, and patching automatically. If you need to download manually, the
release tag format is `v{VERSION}` (e.g. `v7.29.0-18202`) and RPM filenames
follow these patterns:

- x86\_64: `falcon-sensor-{VERSION}.el10.x86_64.rpm`
- aarch64: `falcon-sensor-{VERSION}.el10.aarch64.rpm`

## Obtaining the CID

The CrowdStrike Customer ID (CID) can be obtained from your organisation's
infosec team.

## Encrypting secrets with sops-nix

The CID and repository name are stored alongside the Kolide secret in
`secrets/policy.yaml`:

```bash
cd ~/Zero/nix-config
sops secrets/policy.yaml
```

Add (or update) the `falcon-cid` and `falcon-repo` keys:

```yaml
kolide: <existing-kolide-secret>
falcon-cid: 00000000000000000000000000000000-XX
falcon-repo: owner/repo-name
```

Save and close. sops encrypts the file automatically.

If you have added new age key recipients to `.sops.yaml`:

```bash
sops updatekeys secrets/policy.yaml
```

## Bootstrapping the sensor binaries

The `falcon-sensor-install` script automates the entire bootstrap process:
downloading the RPM, extracting it, copying binaries to `/opt/CrowdStrike/`,
and patching all ELF binaries with the NixOS glibc interpreter.

### Install the latest version

```bash
sudo --preserve-env=GH_TOKEN falcon-sensor-install
```

### Install a specific version

```bash
sudo --preserve-env=GH_TOKEN falcon-sensor-install --version 7.29.0-18202
```

The script will:

1. Detect the host architecture (x86\_64 or aarch64).
2. Read the repository name from the `falcon-repo` sops secret and query the
   latest release (or use the specified version).
3. Download the correct RPM using `gh release download`.
4. Extract the RPM and copy binaries to `/opt/CrowdStrike/`.
5. Stop the `falcon-sensor` service if it is running.
6. Set ownership and permissions (root:root, 0750).
7. Patch all ELF binaries with the NixOS glibc interpreter via `patchelf`.
8. Print next steps for starting the service.

The script requires `GH_TOKEN` or `GITHUB_TOKEN` to be set for `gh` CLI
authentication. Since `sudo` strips environment variables by default, pass
the token explicitly:

```bash
sudo --preserve-env=GH_TOKEN falcon-sensor-install
```

Or pass it inline:

```bash
sudo GH_TOKEN=$GH_TOKEN falcon-sensor-install
```

If you need to authenticate the `gh` CLI first:

```bash
gh auth login
```

## Deploying the configuration

With the CID encrypted in sops and the sensor binaries bootstrapped:

```bash
cd ~/Zero/nix-config
just switch
```

This will:

1. Decrypt `secrets/policy.yaml` and extract the `falcon-cid` secret.
2. Start the `falcon-sensor` systemd service, which configures the CID and BPF
   backend via `falconctl` in its ExecStartPre phase.

## Verifying the installation

The quickest health check is the bundled diagnostic script:

```bash
sudo falcon-sensor-check
```

It walks the service state, sensor configuration, RFM, kernel compatibility,
and log file ownership, and reports each item as `PASS`, `INFO`, or `WARN`.
A healthy host looks roughly like this:

```
Service:    PASS  active (running)
CID:       PASS  configured
AID:        PASS  assigned
Backend:   PASS  bpf
RFM:        PASS  false
Log File:   INFO  /var/log/falconctl.log -> /dev/stdout (captured by journald)
```

For manual checks:

```bash
# Check the service is running
systemctl status falcon-sensor

# View the sensor configuration
sudo /opt/CrowdStrike/falconctl -g --cid --aid --version

# Check Reduced Functionality Mode state (should be false)
sudo /opt/CrowdStrike/falconctl -g --rfm-state

# Check kernel compatibility
sudo /opt/CrowdStrike/falcon-kernel-check

# Follow the logs
journalctl -u falcon-sensor -f
```

A few `errno = 6` lines per boot from `ExecStartPre` are expected and
harmless; see the troubleshooting entry on `/var/log/falconctl.log` below.
If you see repeated `Could not retrieve DisableProxy value: c0000225`
entries, see the corresponding troubleshooting entry.

## Log rotation

The module declares a `services.logrotate.settings."falcon-sensor"` policy
covering the sensor's three on-disk log files:

- `/var/log/falcon-sensor.log`
- `/var/log/falcon-libbpf.log`
- `/var/log/falcond.log`

Retention is daily with seven generations kept, compressed (with
`delaycompress` so the most recent rotation stays plain text for grep),
`missingok`, `notifempty`, and `su root root`. A `maxsize 100M` guard
triggers an out-of-band rotation if a file grows quickly between daily
runs, as a belt-and-braces defence against runaway logging. The policy is
rendered into `/etc/logrotate.conf` and invoked by `logrotate.timer` at
12:00 daily.

Rotation uses `copytruncate` rather than the usual rename-and-reopen dance.
`falcond` holds the log file descriptor open and offers no SIGHUP-style
reopen signal; restarting the EDR sensor purely to reopen its log would
open a blind window in security telemetry, which is unacceptable.
`copytruncate` accepts a brief race on the very last bytes written during
the copy in exchange for keeping the sensor uninterrupted.

`/var/log/falconctl.log` is deliberately excluded. Falcon owns that path
and recreates it as a symlink to `/dev/stdout` at every service start; see
the troubleshooting entry below.

## Updating the sensor

CrowdStrike Falcon does not auto-update on NixOS. To update, re-run the
install script:

```bash
# Update to the latest available version
sudo --preserve-env=GH_TOKEN falcon-sensor-install

# Or pin a specific version
sudo --preserve-env=GH_TOKEN falcon-sensor-install --version 7.30.0-19000
```

The script automatically stops the running service before replacing the
binaries. After the script completes, start the service:

```bash
sudo systemctl start falcon-sensor
```

Or rebuild the full configuration:

```bash
just switch
```

## Troubleshooting

### Service fails to start with "ConditionPathExists" not met

The sensor binaries have not been bootstrapped yet. Run the install script:

```bash
sudo --preserve-env=GH_TOKEN falcon-sensor-install
```

### "falconctl: not found" or binary errors

The ELF binaries were not patched correctly. Re-run the install script to
re-download, re-extract, and re-patch all binaries:

```bash
sudo --preserve-env=GH_TOKEN falcon-sensor-install
```

### Reduced Functionality Mode (RFM)

If `falconctl -g --rfm-state` reports `true`, the sensor is running with
reduced capabilities. This typically happens when the kernel version is not
recognised by the sensor. Check compatibility with:

```bash
sudo /opt/CrowdStrike/falcon-kernel-check
```

If the current kernel is unsupported, updating the sensor to a newer version
(see "Updating the sensor" above) usually resolves RFM.

### Kernel module errors

Falcon must use the BPF backend on NixOS. The ExecStartPre script sets this
automatically. Verify with:

```bash
sudo /opt/CrowdStrike/falconctl -g --backend
```

If it does not show `bpf`, set it manually:

```bash
sudo /opt/CrowdStrike/falconctl -s --backend=bpf
```

### Spurious `DisableProxy` / `c0000225` messages

On hosts with no HTTP proxy in use, `falcond` logs
`Could not retrieve DisableProxy value: c0000225` (NT-status
`STATUS_NOT_FOUND`) on every connect attempt. The sensor falls back to a
direct connection regardless, but the noise drowns out useful log lines.

The module sets `services.falcon-sensor.disableAutoProxyDetection = true`
by default, which adds `falconctl -s --apd=true -f` to `ExecStartPre` and
suppresses the message at source. On `bane` this dropped the count from
505 occurrences in seven days to zero immediately after activation. If a
host genuinely needs proxy auto-detection, override the option to `false`
in its host module.

### `/var/log/falconctl.log` is a symlink to `/dev/stdout`

This is expected. Falcon recreates `/var/log/falconctl.log` as a symlink to
`/dev/stdout` at every service start, regardless of what is on disk; the
file's mtime tracks `ActiveEnterTimestamp` to sub-second precision and
`falconctl` reports `errno = 6` (`ENXIO`) against it on every boot. An
earlier version of the module tried to convert the symlink to a regular
file in `ExecStartPre`; the cleanup never had a chance to take effect
because `falcond` overwrites our touch immediately, and it has been
removed.

All `falconctl` output is captured by journald via systemd's stdout
handling, so observability is unchanged - run `journalctl -u falcon-sensor`
to read it. The four to five `errno = 6` lines per boot from
`ExecStartPre` are harmless and document the historical fight.

Older revisions of `falcon-sensor-check` reported the symlink as `WARN`.
The current script distinguishes the cases:

- symlink to `/dev/stdout` -> `INFO` (expected)
- symlink to anything else -> `WARN` (genuinely unexpected target)
- regular file -> `PASS`
- missing -> `WARN`

### CID not configured

Check the sops secret is being decrypted:

```bash
sudo cat /run/secrets/falcon-cid
```

If the file is missing, verify sops age keys exist at
`/var/lib/private/sops/age/keys.txt` and that the host's public key is listed
as a recipient in `.sops.yaml`.

## Important notes

- **BPF mode only**: the kernel module backend does not work on NixOS. The BPF
  (eBPF) backend is configured automatically by the service's ExecStartPre
  script.
- **Manual updates required**: NixOS's declarative architecture prevents
  Falcon from auto-updating. You are responsible for running
  `sudo --preserve-env=GH_TOKEN falcon-sensor-install` when sensor updates
  are available.
- **Unofficial**: CrowdStrike does not officially support NixOS. This
  configuration is based on community workarounds.
- **Architecture**: the install script automatically detects the host
  architecture and downloads the correct RPM (x86\_64 or aarch64).

## Appendix: relationship to benley/falcon-sensor-nixos

The [`benley/falcon-sensor-nixos`](https://github.com/benley/falcon-sensor-nixos)
project packages the Falcon sensor as a proper Nix derivation using
`autoPatchelfHook` and `buildFHSEnv`. It is a well-crafted solution and
informed several design decisions in our implementation. We diverged where our
operational requirements differed.

### Key differences

| Concern | benley/falcon-sensor-nixos | Our implementation |
| --- | --- | --- |
| **Packaging** | Nix derivation via `autoPatchelfHook` + `buildFHSEnv` | Manual bootstrap with `patchelf --set-interpreter` + `LD_LIBRARY_PATH` |
| **Binary distribution** | `.deb` committed to repo via git-lfs | RPMs downloaded from private GitHub repo at install time |
| **Runtime libraries** | Explicit `openssl`, `zlib`, `libnl` deps | `programs.nix-ld` with `libnl` added explicitly |
| **CID storage** | Plain string in Nix configuration | Encrypted via sops-nix (`/run/secrets/falcon-cid`) |
| **Service ordering** | `sysinit.target` with `DefaultDependencies = false` | `multi-user.target` after `network.target` and `sops-nix.service` |
| **Backend** | Kernel module (default) | BPF (explicitly set via `falconctl`) |
| **Kernel version** | Pinned via `boot.kernelPackages = mkForce` | No kernel pinning |

### Why we diverged

- **No binaries in git.** Committing proprietary packages to a repository,
  even via LFS, is undesirable for licensing and storage reasons.
- **Lighter runtime isolation.** `buildFHSEnv` creates a full FHS namespace;
  `patchelf` + `LD_LIBRARY_PATH` achieves the same result with less overhead.
- **Encrypted secrets.** A plain-text CID in Nix configuration is a security
  concern. sops-nix keeps credentials encrypted at rest.
- **Conservative service ordering.** Starting at `sysinit.target` is too
  aggressive - Falcon needs network connectivity to phone home and we need
  sops-nix to have decrypted the CID first.
- **No forced kernel.** Pinning a kernel version for a security agent is too
  invasive; NixOS kernels update frequently and the BPF backend handles
  version changes gracefully.
- **BPF is the only viable backend.** NixOS cannot load kernel modules from
  `/opt`, so the kernel module backend simply does not work.

### What we adopted

Several patterns from benley's project directly improved our implementation:

- Adding `libnl` as an explicit library dependency (critical for network
  telemetry).
- Using `PIDFile = "/run/falcond.pid"` for reliable service lifecycle
  management.
- Adding `conflicts`/`before` for `shutdown.target` for clean shutdown
  handling.
- Moving CID configuration into `ExecStartPre` rather than activation scripts.
- Tightening tmpfiles permissions to 0750.

Both approaches are valid. Benley's is more "Nix-native" and suits
environments where committing vendor packages is acceptable. Ours prioritises
operational security and minimal system intrusion.
