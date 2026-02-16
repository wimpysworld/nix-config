Borg Backup Modules in NixOS and Home Manager - Research Report
1. Module Overview
Module A: NixOS services.borgbackup.jobs (Backup Client)
What it provides: A first-class NixOS module that wraps raw borg commands into systemd services and timers. Each named job creates:
- A systemd service: borgbackup-job-<NAME>.service
- A systemd timer: borgbackup-job-<NAME>.timer
- A wrapper script: borg-job-<NAME> added to system PATH for manual maintenance
Key configuration options:
| Option | Type | Description |
|--------|------|-------------|
| jobs.<name>.repo | string | Local or remote repo path (e.g. "user@machine:/path") |
| jobs.<name>.paths | list of string | Directories/files to back up |
| jobs.<name>.exclude | list of string | Exclude patterns |
| jobs.<name>.patterns | list of string | Include/exclude patterns with +/- prefixes |
| jobs.<name>.startAt | string or list | systemd calendar expression (default: "daily") |
| jobs.<name>.persistentTimer | boolean | Run missed backups on wake/boot (default: false) |
| jobs.<name>.compression | string | Compression algorithm, e.g. "auto,zstd" |
| jobs.<name>.encryption.mode | enum | repokey, keyfile, repokey-blake2, keyfile-blake2, authenticated, authenticated-blake2, none |
| jobs.<name>.encryption.passCommand | string | Command to retrieve passphrase (sops-compatible) |
| jobs.<name>.prune.keep | attrset | Retention: within, daily, weekly, monthly, yearly |
| jobs.<name>.preHook | string | Shell commands before backup |
| jobs.<name>.postCreate | string | Shell commands after archive creation ($archiveName available) |
| jobs.<name>.postPrune | string | Shell commands after pruning |
| jobs.<name>.postHook | string | Shell commands at exit (even on failure, $exitStatus available) |
| jobs.<name>.user | string | User to run as (default: "root") |
| jobs.<name>.group | string | Group to run as |
| jobs.<name>.inhibitsSleep | boolean | Prevent system sleep during backup |
| jobs.<name>.removableDevice | boolean | Skip init if device not mounted |
| jobs.<name>.doInit | boolean | Auto-initialise repo if it doesn't exist |
| jobs.<name>.environment | attrset | Environment variables (e.g. SSH key path) |
| jobs.<name>.readWritePaths | list | Extra paths the sandboxed service can write to |
| jobs.<name>.privateTmp | boolean | Isolate /tmp for the service |
| jobs.<name>.extraCreateArgs | string/list | Extra arguments to borg create |
| jobs.<name>.extraPruneArgs | string/list | Extra arguments to borg prune |
| jobs.<name>.dumpCommand | path | Pipe a command's stdout instead of filesystem paths |
Scheduling: Uses systemd OnCalendar expressions via startAt. Supports any valid systemd.time(7) format including "hourly", "daily", "*:0/15" (every 15 minutes), etc. Each job gets its own independent timer. Persistent timers catch up after missed runs.
Multiple jobs: Fully supported - each key in jobs.<name> is an independent backup job with its own schedule, paths, repo, encryption, and retention. You can define as many as you like.
Remote repositories: Fully supported. Set repo = "user@host:path" or repo = "ssh://user@host/path". Use environment.BORG_RSH to configure SSH options (identity file, port). Works naturally over Tailscale by using the Tailscale hostname.
Encryption: Full support for all borg encryption modes. passCommand is ideal for integration with sops-nix (e.g. passCommand = "cat /run/secrets/borg-passphrase").
Pre/post hooks: Comprehensive hook system with five hook points: preHook, postInit, postCreate, postPrune, postHook. The postHook always runs (even on failure) with $exitStatus available - perfect for notifications.
Pruning: Built-in via prune.keep with the standard borg retention keys. Pruning runs automatically after each backup.
---
Module B: NixOS services.borgbackup.repos (Repo Server)
What it provides: Configures the host to serve borg repositories over SSH. Creates restricted SSH access so that clients can only run borg serve against the specified repository. This is the server-side companion to services.borgbackup.jobs.
Key configuration options:
| Option | Type | Description |
|--------|------|-------------|
| repos.<name>.path | absolute path | Where to store backups (default: /var/lib/borgbackup) |
| repos.<name>.authorizedKeys | list of string | SSH public keys with full read/write access |
| repos.<name>.authorizedKeysAppendOnly | list of string | SSH keys that can only append (no delete/prune) |
| repos.<name>.user | string | User that borg serve runs as |
| repos.<name>.group | string | Group for the service |
| repos.<name>.quota | string | Storage quota (e.g. "100G") |
| repos.<name>.allowSubRepos | boolean | Allow clients to create sub-repositories |
What it does under the hood:
- Creates a dedicated system user per repo
- Adds SSH authorized_keys entries with command="borg serve --restrict-to-path ..." restrictions
- Automatically creates the repository directory with correct permissions
- Supports append-only mode for clients (defence against ransomware - clients can write but not delete)
This is exactly what you need for the home server acting as a remote repo target.
---
Module C: NixOS services.borgmatic (Borgmatic Wrapper)
What it provides: A NixOS module for borgmatic (https://torsion.org/borgmatic/), which is a YAML-driven wrapper around borg. It creates a single systemd timer (borgmatic.timer) that triggers all configured borgmatic configurations.
Key configuration options:
| Option | Type | Description |
|--------|------|-------------|
| enable | boolean | Enable borgmatic |
| enableConfigCheck | boolean | Validate configs at build time (default: true) |
| settings | YAML submodule | Global borgmatic settings (shared across all configs) |
| configurations.<name> | YAML submodule | Named borgmatic configurations - open-ended YAML |
| configurations.<name>.source_directories | list of string | Directories to back up |
| configurations.<name>.repositories | list of {path, label} | Target repositories |
Scheduling: The NixOS borgmatic module creates a single borgmatic.timer that runs all configurations together. The scheduling is controlled at the systemd timer level, not per-configuration. This is a significant limitation - you cannot natively have one borgmatic configuration run hourly and another daily from this module.
Multiple configurations: Supported via configurations.<name>, but all share the same timer. The configurations option is an open YAML submodule, meaning you can pass any valid borgmatic YAML configuration keys directly. This is very flexible (borgmatic supports hooks, healthchecks, database dumps, etc.) but provides no Nix-level type checking beyond basic YAML structure.
Remote repositories: Supported through borgmatic's YAML config (ssh_command, repository paths).
Encryption: Configured through the open YAML submodule (not first-class Nix options).
Hooks: Borgmatic has rich hook support (before_backup, after_backup, on_error, healthchecks, ntfy, etc.) but these are configured as raw YAML, not typed Nix options.
Pruning: Configured through YAML retention section.
---
Module D: Home Manager programs.borgmatic (Borgmatic Configuration)
What it provides: Generates borgmatic YAML configuration files in ~/.config/borgmatic.d/. Does NOT create any systemd services or timers on its own - it only writes config files. Must be paired with services.borgmatic to actually run backups.
Key configuration options:
| Option | Type | Description |
|--------|------|-------------|
| enable | boolean | Enable borgmatic config generation |
| package | package | The borgmatic package |
| backups.<name>.location.sourceDirectories | list of string | Directories to back up |
| backups.<name>.location.repositories | list of {path, label} | Target repositories |
| backups.<name>.location.patterns | list of string | Include/exclude patterns |
| backups.<name>.location.excludeHomeManagerSymlinks | boolean | Exclude HM-generated symlinks |
| backups.<name>.location.extraConfig | YAML | Extra location settings |
| backups.<name>.retention.keepHourly | integer | Hourly archives to keep |
| backups.<name>.retention.keepDaily | integer | Daily archives to keep |
| backups.<name>.retention.keepWeekly | integer | Weekly archives to keep |
| backups.<name>.retention.keepMonthly | integer | Monthly archives to keep |
| backups.<name>.retention.keepYearly | integer | Yearly archives to keep |
| backups.<name>.retention.keepWithin | string | Keep all within time period |
| backups.<name>.storage.encryptionPasscommand | string | Passphrase command |
| backups.<name>.consistency.checks | list of {name, frequency} | Consistency checks |
| backups.<name>.hooks.extraConfig | YAML | Hooks (before_backup, etc.) |
Scheduling: None. This module only generates config files. You need services.borgmatic to create the timer.
Multiple backups: Each key in backups.<name> generates a separate borgmatic config file in ~/.config/borgmatic.d/<name>.yaml. When borgmatic runs, it picks up all configs from that directory.
Home Manager-specific features:
- excludeHomeManagerSymlinks: Automatically excludes Home Manager symlinks from backups - very useful for home directory backups where you don't want to back up Nix store symlinks.
---
Module E: Home Manager services.borgmatic (Borgmatic Timer)
What it provides: A minimal module that creates a user-level systemd timer to run borgmatic on a schedule. This is the companion to programs.borgmatic.
Key configuration options:
| Option | Type | Description |
|--------|------|-------------|
| enable | boolean | Enable the borgmatic systemd user timer |
| frequency | string | systemd OnCalendar expression (default: "daily") |
Critical limitation: There is only a single frequency option. All borgmatic configs in ~/.config/borgmatic.d/ run on the same schedule. You cannot have different schedules for different backup groups through this module alone.
---
2. Comparison Table
| Feature | NixOS borgbackup.jobs | NixOS borgbackup.repos | NixOS borgmatic | HM programs.borgmatic | HM services.borgmatic |
|---|---|---|---|---|---|
| Purpose | Backup client | Repo server | Backup client (borgmatic) | Config generation only | Timer only |
| Runs as | System service (any user) | SSH-restricted serve | System service | N/A (config files) | User systemd timer |
| Multiple jobs | Yes, independent | Yes, independent repos | Yes, but shared timer | Yes, separate configs | N/A |
| Independent schedules | Yes - per job | N/A | No - single timer | N/A | No - single frequency |
| Scheduling format | systemd.time(7) | N/A | systemd.time(7) | N/A | systemd.time(7) |
| Persistent timer | Yes (persistentTimer) | N/A | Not exposed | N/A | Not exposed |
| Remote repo support | Yes (SSH) | Yes (serves repos) | Yes (via YAML) | Yes (via YAML) | N/A |
| Encryption | First-class typed options | N/A | Via open YAML | encryptionPasscommand | N/A |
| Pre/post hooks | 5 typed hook points | N/A | Via open YAML | Via extraConfig | N/A |
| Pruning | First-class prune.keep | N/A | Via open YAML | First-class retention options | N/A |
| Exclude patterns | exclude + patterns | N/A | Via open YAML | patterns + extraConfig | N/A |
| Inhibit sleep | Yes | N/A | No | N/A | N/A |
| Removable device | Yes | N/A | No | N/A | N/A |
| Wrapper scripts | Yes (borg-job-NAME) | N/A | borgmatic CLI | borgmatic CLI | N/A |
| Config validation | Nix type-checked | Nix type-checked | Build-time YAML check | Nix type-checked | N/A |
| Append-only clients | N/A | Yes | N/A | N/A | N/A |
| Quota support | N/A | Yes | N/A | N/A | N/A |
| Exclude HM symlinks | No | N/A | No | Yes | N/A |
| Runs as user | Configurable | Dedicated user | root | N/A | User session |
| Sandboxing | PrivateTmp, readWritePaths | N/A | Limited | N/A | None |
3. Pros and Cons
NixOS services.borgbackup.jobs
Pros:
- Independent schedules per job - each job has its own startAt, which directly solves the two-schedule-group requirement (hourly vs daily)
- Fully typed Nix options - encryption, compression, pruning, hooks all have proper types with build-time validation
- Persistent timers - catches up on missed backups after sleep/shutdown, critical for workstations
- Inhibit sleep - prevents the system suspending mid-backup
- Wrapper scripts - borg-job-NAME makes manual operations (list, mount, extract) trivial
- Mature and well-maintained - the most established borg module in nixpkgs
- Can run as any user - set user = "martin" to back up home directories without root
- Direct sops integration - passCommand = "cat /run/secrets/borg-pass" works naturally
- Remote repos - first-class repo = "user@host:." with environment.BORG_RSH for SSH options
Cons:
- NixOS-level only - configuration lives in NixOS modules, not Home Manager; less portable if you wanted to use the same config on non-NixOS
- No HM symlink exclusion - you'd need to manually add exclusion patterns for Home Manager symlinks
- No borgmatic extras - no built-in healthcheck pings, database dump hooks, or ntfy integration (though postHook can do all of this via shell)
- Root default - runs as root by default; you must explicitly set user/group for non-root operation
NixOS services.borgbackup.repos
Pros:
- Purpose-built for serving repos - automatic user creation, SSH restriction, directory provisioning
- Append-only mode - authorizedKeysAppendOnly for defence-in-depth against compromised clients
- Quota support - limit per-client storage usage
- Pairs perfectly with borgbackup.jobs - designed to work together
- Minimal attack surface - clients can only run borg serve, nothing else
Cons:
- SSH-only - no native support for other transports (not really a con for Tailscale)
- One user per repo - creates system users, which is fine but worth knowing
- No monitoring - no built-in alerting if clients stop backing up
NixOS services.borgmatic
Pros:
- Open YAML passthrough - can use any borgmatic feature, including healthcheck pings, database hooks, ntfy notifications, monitoring integrations
- Build-time config validation - enableConfigCheck validates all YAML at build time
- Named configurations - logical grouping of backup sources
- Borgmatic CLI - rich CLI for listing, extracting, checking backups
Cons:
- Single timer for all configurations - cannot have hourly and daily backup groups; this is a deal-breaker for the workstation requirement
- Open YAML = weak typing - most options are untyped; errors only caught by borgmatic's own validation, not Nix's type system
- Runs as root - no user option exposed
- No persistent timer option exposed - harder to ensure catch-up on laptops/workstations
- No sleep inhibition - no inhibitsSleep equivalent
Home Manager programs.borgmatic + services.borgmatic
Pros:
- Home Manager native - configuration lives alongside other user-level config; fits the mixin pattern for home directory backups
- excludeHomeManagerSymlinks - automatically excludes HM-generated symlinks, avoiding Nix store noise in backups
- Typed retention options - keepHourly, keepDaily, etc. are proper Nix options
- Named backups - each backup is a separate config file in ~/.config/borgmatic.d/
- User-level systemd - runs in user session, no root needed
- extraConfig escape hatches - can add any borgmatic YAML via hooks.extraConfig, location.extraConfig, etc.
Cons:
- Single frequency for all backups - services.borgmatic.frequency is a single value; all configs run on the same schedule. Same deal-breaker as the NixOS borgmatic module
- No persistent timer - missed backups after sleep are not automatically caught up
- No sleep inhibition - system could suspend mid-backup
- User-level systemd limitations - timers only fire when the user session is active (logged in); may not fire if nobody is logged in
- Config generation only - programs.borgmatic just writes YAML files; services.borgmatic is needed to actually run them
- Stale option structure - the HM module uses borgmatic's older config structure (location, storage, retention sections) which maps to borgmatic <1.8 format; borgmatic 1.8+ uses a flat config format
4. Recommendation
The Winning Combination
Use services.borgbackup.jobs for all backup jobs, and services.borgbackup.repos on the home server. This is the strongest approach for your requirements. Here's why:
---
Workstations: Two Schedule Groups
services.borgbackup.jobs is the only module that supports independent schedules per job. Define two jobs:
services.borgbackup.jobs = {
  # Group A: Hourly backups of critical directories
  home-hourly = {
    startAt = "hourly";
    persistentTimer = true;
    inhibitsSleep = true;
    paths = [
      "/home/martin/Documents"
      "/home/martin/Projects"
      "/home/martin/.config"
      # ... other critical paths
    ];
    repo = "/backup/borg/hourly";
    user = "martin";
    group = "users";
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat /run/secrets/borg-passphrase";
    compression = "auto,zstd";
    prune.keep = {
      within = "1d";
      hourly = 24;
      daily = 7;
    };
    exclude = [
      "*.pyc"
      "__pycache__"
      "node_modules"
      ".cache"
    ];
  };
  # Group B: Daily backups of larger directories
  home-daily = {
    startAt = "daily";
    persistentTimer = true;
    inhibitsSleep = true;
    paths = [
      "/home/martin/Pictures"
      "/home/martin/Music"
      "/home/martin/Videos"
      # ... other large/less-critical paths
    ];
    repo = "/backup/borg/daily";
    user = "martin";
    group = "users";
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat /run/secrets/borg-passphrase";
    compression = "auto,zstd";
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };
};
Neither the NixOS borgmatic module nor the Home Manager borgmatic module can do this - they both have a single shared timer.
---
Home Server: Media Backups
Same module, straightforward:
services.borgbackup.jobs = {
  media = {
    startAt = "daily";
    persistentTimer = true;
    paths = [
      "/media/films"
      "/media/tv"
      "/media/music"
    ];
    repo = "/mnt/backup-array/borg/media";
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat /run/secrets/borg-passphrase";
    compression = "auto,zstd,3";  # Lower compression for media (already compressed)
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 3;
    };
  };
};
---
Home Server as Remote Repo Target
On the home server, use services.borgbackup.repos to serve repos for workstations:
services.borgbackup.repos = {
  vader = {
    path = "/mnt/backup-array/borg/remote/vader";
    authorizedKeys = [ "ssh-ed25519 AAAA... borg@vader" ];
    # Or append-only for defence against compromised workstations:
    # authorizedKeysAppendOnly = [ "ssh-ed25519 AAAA... borg@vader" ];
    quota = "500G";
  };
  # Repeat for each workstation
};
Then on the workstation, add a third job that pushes to the remote repo over Tailscale:
services.borgbackup.jobs = {
  # ... home-hourly and home-daily as above ...
  remote-offsite = {
    startAt = "daily";
    persistentTimer = true;
    paths = [
      "/home/martin/Documents"
      "/home/martin/Projects"
      # The most critical stuff
    ];
    repo = "borg@homeserver-tailscale:."  ;  # Tailscale hostname
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat /run/secrets/borg-passphrase-remote";
    compression = "auto,zstd";
    environment.BORG_RSH = "ssh -i /run/secrets/borg-ssh-key";
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 12;
    };
  };
};
---
Why Not Home Manager borgmatic?
While programs.borgmatic does have the nice excludeHomeManagerSymlinks feature, the critical downsides outweigh it:
1. Cannot do two schedules - the single frequency option is a blocker
2. User-level timers - won't fire reliably if the user isn't logged in
3. No persistent timers - missed backups on a workstation that sleeps/suspends are silently lost
4. No sleep inhibition - backup could be killed mid-write by a suspend
5. Stale config format - the module uses the older borgmatic config structure
The excludeHomeManagerSymlinks feature can be replicated with a few exclude patterns in services.borgbackup.jobs:
exclude = [
  "sh:/home/martin/.nix-profile"
  "sh:/home/martin/.local/state/nix"
  "sh:/home/martin/.local/state/home-manager"
];
---
Where Should Config Live?
NixOS-level (nixos/_mixins/), not Home Manager. Even though you're backing up home directories, the borgbackup jobs module offers system-level features you need:
- Persistent timers (survives sleep/reboot)
- Sleep inhibition
- Sandboxed systemd services
- Root-capable wrapper scripts for restore operations
- Integration with sops-nix system-level secrets
Place it in a mixin like nixos/_mixins/services/borgbackup/default.nix and conditionally import it on workstations and servers with different job definitions.
---
Does Borgmatic Add Value?
Not enough to justify its limitations. Borgmatic's main selling points are:
- YAML config files (less relevant when you have Nix)
- Healthcheck/monitoring integrations (achievable via postHook)
- Database dump hooks (not needed for your use case)
Everything borgmatic adds can be done with preHook/postHook in the borgbackup module, and you gain independent schedules, persistent timers, sleep inhibition, and full Nix type checking in return.
---
Summary
| Requirement | Solution |
|---|---|
| Workstation hourly backups (Group A) | services.borgbackup.jobs.home-hourly with startAt = "hourly" |
| Workstation daily backups (Group B) | services.borgbackup.jobs.home-daily with startAt = "daily" |
| Server media backups | services.borgbackup.jobs.media with startAt = "daily" |
| Server as remote repo | services.borgbackup.repos.<workstation> with append-only keys |
| Workstation remote push | services.borgbackup.jobs.remote-offsite with Tailscale hostname |
| Encryption | encryption.mode = "repokey-blake2" + sops-nix passCommand |
| Catch-up after sleep | persistentTimer = true on all workstation jobs |
| Prevent mid-backup suspend | inhibitsSleep = true on workstation jobs |
| Config location | nixos/_mixins/services/borgbackup/ mixin |
