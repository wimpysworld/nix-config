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

- **Authenticated:** Uses `fh resolve` to pull pre-built closures from FlakeHub Cache, skipping local compilation. Falls back to local build if resolution fails.
- **Not authenticated or unavailable:** Builds everything locally from the flake. Slower but fully functional.

No files need to be injected for FlakeHub, authentication is handled interactively on the ISO host. No flags are needed, the script detects what is available.

## What the script does

1. **Clone the repo** - Clones `nix-config` to `~/Zero/nix-config` if not already present, checks out the requested branch
2. **Ingest tokens** - Copies any files from `/tmp/injected-tokens/` to their final locations, then cleans up the staging directory
3. **Validate keys** - Checks that both user and host age keys exist at their final paths; aborts with a helpful message if not
4. **Detect FlakeHub** - Checks `determinate-nixd status`; prompts for login if needed; sets the install path accordingly
5. **Prepare disks** - Runs [Disko] to partition and format the target disk(s) using the host's `disks.nix` (prompts for confirmation before destructive operations)
6. **Install NixOS** - Runs `nixos-install` using either FlakeHub Cache or the local flake
7. **Copy secrets to target** - Copies the host age key and user age key to the mounted target filesystem
8. **Inject SSH keys** - Decrypts initrd and per-host SSH keys from sops-encrypted secrets and writes them to `/mnt/etc/ssh/`
9. **Rsync the flake** - Copies `~/Zero/` to the target user's home directory
10. **Activate Home Manager** - Chroots into the new system and runs `home-manager switch` (via FlakeHub or local build)

## LUKS disk encryption

If the host's `disks.nix` references `data.passwordFile`, the script prompts for a disk encryption password (with confirmation) and writes it to `/tmp/data.passwordFile` for Disko.

If the disk configuration references a `keyFile`, the script generates a random 4096-byte LUKS key at `/tmp/luks.key` and copies it to `/mnt/etc/luks.key` after formatting.

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
