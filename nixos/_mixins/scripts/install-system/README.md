# install-system

Bootstraps a NixOS installation from ISO media onto a target disk. Handles disk partitioning, secret injection, NixOS installation and Home Manager activation in a single interactive run.

## Usage

```bash
install-system <hostname> [username] [branch]
```

| Argument   | Required | Default  | Description                       |
|------------|----------|----------|-----------------------------------|
| `hostname` | Yes      |          | NixOS configuration to install    |
| `username` | No       | `martin` | Target user account               |
| `branch`   | No       | `main`   | Git branch to clone and check out |

## Prerequisites

1. Boot the target machine from an ISO built by this flake (`just iso console`)
2. Ensure the network is available (the ISO enables SSH by default)
3. Inject tokens from a trusted workstation (see below)

## Token injection

Before running `install-system`, push the required secrets from your workstation to the ISO host:

```bash
just inject-tokens <ip-address>
```

This transfers two files via SCP:

| Token              | Source (workstation)                   | Purpose                                    |
|--------------------|----------------------------------------|--------------------------------------------|
| User SOPS age key  | `~/.config/sops/age/keys.txt`          | Decrypt sops-managed secrets during install |
| Host SOPS age key  | `/var/lib/private/sops/age/keys.txt`   | Decrypt sops-managed secrets at boot        |

Files land in `/tmp/injected-tokens/` on the ISO (RAM-backed tmpfs). When `install-system` starts, it copies them to their final locations and deletes the staging directory.

The `inject-tokens` recipe accepts an optional `user` parameter (default: `nixos`) for the SSH user on the ISO.

### Age key requirements

Both age keys are **hard requirements**. The script aborts if either is missing after ingestion. If you see the error, run `just inject-tokens <ip>` from your workstation and try again.

- **User age key** - decrypts SSH host keys and other sops-managed secrets during the install
- **Host age key** - copied to the target system so it can decrypt secrets at boot

### FlakeHub authentication (optional)

FlakeHub Cache requires `determinate-nixd` to be authenticated. During install, if `determinate-nixd` is available but not logged in, the script prompts you to run `determinate-nixd login` interactively.

- **Authenticated:** Uses `fh resolve` to pull pre-built closures from FlakeHub Cache for both NixOS system installation and Home Manager activation, skipping local compilation. Falls back to local build if resolution fails.
- **Not authenticated or unavailable:** Builds everything locally from the flake. Slower but fully functional.

No files need to be injected for FlakeHub, authentication is handled interactively on the ISO host. No flags are needed, the script detects what is available.

## What the script does

1. **Clone the repo** - Clones `nix-config` to `~/Zero/nix-config` if not already present, checks out the requested branch
2. **Ingest tokens** - Copies any files from `/tmp/injected-tokens/` to their final locations, then cleans up the staging directory
3. **Validate keys** - Checks that both user and host age keys exist at their final paths; aborts with a helpful message if not
4. **Detect FlakeHub** - Checks `determinate-nixd status`; prompts for login if needed; sets the install path accordingly
5. **Prepare disks** - Runs [Disko] to partition and format the target disk(s) using the host's `disks.nix` (prompts for confirmation before destructive operations)
6. **Install NixOS** - Runs `nixos-install` with `--no-channel-copy` using either FlakeHub Cache or the local flake; cleans up any channel artefacts afterwards
7. **Copy secrets to target** - Copies the host age key and user age key to the mounted target filesystem
8. **Inject SSH keys** - Cleans and recreates `/mnt/etc/ssh/`, then decrypts initrd and per-host SSH keys from sops-encrypted secrets
9. **Rsync the flake** - Copies `~/Zero/` to the target user's home directory
10. **Activate Home Manager** - When FlakeHub is available, resolves the Home Manager store path and copies the closure to the target's Nix store outside the chroot (where FlakeHub auth works), then activates directly from that store path inside the chroot. Falls back to a local build via `nix run nixpkgs#home-manager` if FlakeHub resolution fails. Without FlakeHub, builds locally from the flake

## LUKS disk encryption

If the host's `disks.nix` references `data.passwordFile`, the script prompts for a disk encryption password (with confirmation) and writes it to `/tmp/data.passwordFile` for Disko. If the disk configuration references a `keyFile`, the script generates a random 4096-byte LUKS key at `/tmp/luks.key` and copies it to `/mnt/etc/luks.key` after formatting.

Both prompts happen **inside** the Disko formatting step, only when you confirm the format prompt with "Y". On mount-only re-runs (answering "N" to the format prompt), the password and keyfile prompts are skipped entirely.

## Re-runs and idempotency

The install can fail mid-way (network timeouts, build errors, etc.) and the script can be re-run safely:

- **Disko re-run** - When prompted to format disks, answering "N" performs a mount-only operation. No LUKS password or keyfile prompts appear in this case.
- **SSH key cleanup** - `/mnt/etc/ssh` is cleaned and recreated on each run to avoid permission conflicts from previous attempts.
- **Channel cleanup** - Channel artefacts left by `nixos-install` are removed after each run to prevent spurious warnings.

### Network resilience

The `nix build` pre-copy step was introduced purely for UX - a single progress bar instead of thousands of noisy "copying path" lines. An accidental side benefit is that it makes the entire install remarkably resilient to flaky networks.

Each pre-copy runs with `|| true`, making it best-effort. If a network timeout interrupts `nix build` after downloading 4,000 of 5,000 paths, the script continues to the next operation (`nixos-install` or Home Manager activation) which finds those 4,000 paths already in the store and only fetches the remaining 1,000. This gives two bites at the apple within a single run - no need to re-run the script after a transient failure. Nix registers store paths atomically, so partially-downloaded runs leave the store in a clean state. If the script does need re-running, `nix build` resumes from where it left off rather than starting from scratch.

One gap: the [Disko] tool itself is pre-fetched, but disko's internal `nix-build` for runtime dependencies (~51 paths, ~15 MiB) is a separate fetch phase not covered by the pre-copy.

## Example

From your workstation:

```bash
# 1. Inject tokens to the ISO host
just inject-tokens 192.168.1.42

# 2. SSH into the ISO host
ssh nixos@192.168.1.42

# 3. Run the installer
install-system vader
```

The script will prompt for FlakeHub login during install if `determinate-nixd` is available but not authenticated.

Make a cuppa while it builds. Reboot when done.

[Disko]: https://github.com/nix-community/disko
