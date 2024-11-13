# GoToSocial Backup Script

A comprehensive backup script for [GoToSocial](https://gotosocial.org/) instances that handles data export, SQLite database backup, and local-only media file backup with incremental storage using hardlinks.

## Features

- Complete instance backup including:
  - GoToSocial data export
  - SQLite database backup with integrity checking
  - Media files backup (attachments and emoji)
- Incremental backups using hardlinks to save space
- Configurable retention period
- Automatic log rotation
- Verification of backup integrity
- Support for both NixOS and traditional Linux distributions

## Requirements

- Bash
- SQLite3
- rsync
- GoToSocial instance
- Root access

## Installation

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/wimpysworld/nix-config/main/nixos/_mixins/services/gotosocial/gotosocial-backup.sh
```

2. Make it executable:
```bash
chmod 700 backup-gotosocial.sh
chown root:root backup-gotosocial.sh
```

## Configuration

The script can be configured by editing the following variables at the top of the file:

```bash
# Root directory for backups
BACKUP_ROOT="/mnt/data/backup/gotosocial"
# Path to GoToSocial configuration file
GTS_CONFIG="/etc/gotosocial/config.yaml"
# Path to the GoToSocial SQLite database
GTS_DB="/var/lib/gotosocial/database.sqlite"
# Retention period in days
RETENTION_DAYS=28
```

### Additional Configuration Options

The script also maintains a log file that is automatically rotated.
You can adjust the number of lines kept in the log by modifying:

```bash
LOGLINES=4096
```

## Distribution-specific Notes

### NixOS

On NixOS, the script automatically detects and uses the `gotosocial-admin` helper script if it's available at `/run/current-system/sw/bin/gotosocial-admin`. No additional configuration is needed.

### Traditional Linux Distributions

On traditional Linux distributions, the script requires the `gotosocial` binary to be in the system PATH and uses the specified configuration file path (`GTS_CONFIG`).

## Usage

### Manual Execution

Run the script as root:

```bash
sudo ./backup-gotosocial.sh
```

[Previous sections remain the same until "Automated Backups"]

## Automated Backups

### Using Cron

Add to root's crontab for automated backups:

```bash
sudo crontab -e
```

Add a line for hourly backups:

```bash
0 * * * * /path/to/backup-gotosocial.sh
```

### Using systemd Timer

For systems using systemd, you can create a timer unit to schedule backups.
This provides better logging and monitoring capabilities compared to cron.

1. Create the service unit file at `/etc/systemd/system/gotosocial-backup.service`:

```ini
[Unit]
Description=GoToSocial Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/backup-gotosocial.sh
User=root
Group=root

# Security settings
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
NoNewPrivileges=true
ReadWritePaths=/mnt/data/backup/gotosocial /var/lib/gotosocial /tmp

[Install]
WantedBy=multi-user.target
```

2. Create the timer unit file at `/etc/systemd/system/gotosocial-backup.timer`:

```ini
[Unit]
Description=Run GoToSocial Backup hourly

[Timer]
OnCalendar=hourly
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
```

3. Enable and start the timer:

```bash
# Reload systemd to recognize new units
sudo systemctl daemon-reload

# Enable timer to run at boot
sudo systemctl enable gotosocial-backup.timer

# Start the timer
sudo systemctl start gotosocial-backup.timer
```

4. Verify the timer is active:

```bash
# Check timer status
sudo systemctl status gotosocial-backup.timer

# List all timers
sudo systemctl list-timers
```

5. Monitor backup execution:

```bash
# View service logs
sudo journalctl -u gotosocial-backup.service

# Follow logs in real-time
sudo journalctl -u gotosocial-backup.service -f
```

The systemd timer configuration includes:
- Random delay of up to 5 minutes to prevent exact-hour execution
- Persistent timing to catch up on missed backups after system downtime
- Security hardening through systemd service restrictions
- Proper logging integration with journald
- Read-only access to most of the filesystem
- Explicit write access only to required paths

## Backup Structure

The script creates timestamped backup directories:

```
/mnt/data/backup/gotosocial/
├── 20241113_180102
   │  ├── database.sqlite.gz
   │  ├── export.json.gz
   │  └── mnt
   │     └── data
   │        └── gotosocial
   │           └── storage
   │              ├── 01CCJ5GQF7A2KXVDPQ9Q9X23Q2
   │              │  └── attachment
   │              │     └── original
   │              │        ├── 01JCF13JSSDJ0H8E9CWFFW2GVZ.png
   │              │        └── 01JCF13K0R2HJDZWTPWGRNAPZ2.jpeg
   │              ├── 01H7KYSZYN26CWTKT9JNKSZ2XB
   │              │  ├── attachment
   │              │  │  └── original
   │              │  │     └── 01JCF1V56JDJ3SW03V82PFSQ37.png
   │              │  └── emoji
   │              │     └── original
   │              │        └── 01JCJPE20Z1EYX3RTFBVTMM8JB.png
   │              └── 01NATX9MGDJF8ESH0Q4TD5VAV7
   │                 └── attachment
   │                    └── original
   │                       ├── 01JCF2RK21FM491KRKSFTBFXWD.png
   │                       └── 01JCF2X4KN3032X5ZHRZ94H5MQ.png
   ├── backup.log
   └── latest -> /mnt/data/backup/gotosocial/20241113_180102
```

Each backup includes:
- Compressed SQLite database backup (`database.sqlite.gz`)
- Compressed GoToSocial export (`export.json.gz`)
- Media files (attachments and emoji) with preserved directory structure
- A `latest` symlink pointing to the most recent successful backup

## Log File

The script maintains a log file at `$BACKUP_ROOT/backup.log`.
The log is automatically rotated to keep the most recent 4096 lines by default.

## Backup Retention

The script maintains backups according to these rules:
1. Keeps all backups from the current day
2. Keeps all backups newer than the retention period
3. Removes backups that are both:
   - Older than the retention period
   - Not from the current day

## Error Handling

The script includes comprehensive error checking:
- Verifies root access
- Checks for required tools
- Validates database accessibility
- Performs SQLite integrity checks
- Verifies backup completeness
- Cleans up temporary files on exit

## Security

The script:
- Requires root privileges
- Sets secure permissions (700) on backup directories
- Sets secure permissions (600) on log files
- Uses temporary files securely
- Cleans up temporary files automatically
