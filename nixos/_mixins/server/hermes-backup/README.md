# Hermes Cloudflare R2 backup scripts

This mixin installs three root-oriented helper commands on Hermes-tagged hosts:

- `hermes-backup-r2` creates and uploads an encrypted backup archive and manifest.
- `hermes-backup-verify-r2` downloads a backup archive and manifest, then verifies the manifest metadata, archive hash, archive size, and archive structure.
- `hermes-restore-r2` restores a chosen backup into an explicit destination directory.

## Usage

Run the commands as `root` so they can read the rendered SOPS environment file and the Hermes state data.

```bash
sudo hermes-backup-r2
sudo hermes-backup-verify-r2
sudo hermes-backup-verify-r2 2026-04-21T00-00-00Z
sudo hermes-restore-r2 2026-04-21T00-00-00Z /var/tmp/hermes-restore/2026-04-21T00-00-00Z
```

The verification command accepts either a full archive name such as `2026-04-21T00-00-00Z.tar.zst` or just the timestamp prefix. With no argument it verifies the latest complete backup for the current host.

The restore command always requires two arguments:

1. The backup timestamp or archive name to restore.
2. The absolute destination path to extract into.

## Restore safety checks

The restore flow refuses:

- missing destination arguments
- relative destination paths
- `/`, `/var`, `/var/lib`, or `/var/lib/hermes`
- any destination nested under `/var/lib/hermes`
- symbolic-link destinations
- existing non-empty destination directories

Restores are therefore forced into an explicit, separate target path instead of overwriting the live Hermes state in place.
