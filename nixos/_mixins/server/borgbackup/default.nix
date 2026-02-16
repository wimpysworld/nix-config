{
  config,
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];

  # Legacy hosts store backups under /mnt/snapshot; newer hosts use /mnt/data.
  legacyHosts = [
    "phasma"
    "revan"
    "vader"
  ];
  backupBase = if lib.elem hostname legacyHosts then "/mnt/snapshot" else "/mnt/data";
  home = "/home/${username}";
  domain = config.services.nullmailer.config.defaultdomain;

  # Derive the borg repository path for a given job name.
  repoPrefix = "${backupBase}/${username}/borg-${hostname}-";
  mkRepoPath = name: "${repoPrefix}${name}";

  # Structured backup job definitions. Each entry describes what to back up,
  # when to run, and how long to retain archives.
  backupJobs = {
    data = {
      compression = "auto,zstd,3";
      startAt = "hourly";
      paths = [
        "${home}/Apps"
        "${home}/Chainguard"
        "${home}/Crypt"
        "${home}/Development"
        "${home}/Documents"
        "${home}/Downloads"
        "${home}/Dropbox"
        "${home}/Public"
        "${home}/Websites"
        "${home}/Zero"
      ];
      exclude = [
        # Build artefacts
        "*.pyc"
        "__pycache__"
        "node_modules"
        ".direnv"
        ".devenv"
        ".git/objects"
        "result"
        "target/debug"
        "target/release"
        ".tox"
        ".venv"

        # Caches and regenerable state
        ".cache"
        ".cargo/registry"
        ".rustup/toolchains"
        ".gradle"
        ".local/share/Trash"
        ".thumbnails"

        # Nix store symlinks (not useful without /nix/store)
        ".nix-profile"
        ".nix-defexpr"
        ".local/state/nix"
        ".local/state/home-manager"

        # Editor temporaries
        "*.swp"
        "*.swo"
        "*~"
      ];
      prune.keep = {
        hourly = 48;
        daily = 14;
        weekly = 4;
        monthly = 12;
        yearly = 3;
      };
    };
    media = {
      compression = "auto,lz4";
      startAt = "*-*-* 03:00:00";
      paths = [
        "${home}/Audio"
        "${home}/Games"
        "${home}/Music"
        "${home}/Pictures"
        "${home}/Studio"
        "${home}/Videos"
      ];
      exclude = [
        ".cache"
        "*.tmp"
      ];
      prune.keep = {
        hourly = 24;
        daily = 10;
        weekly = 4;
        monthly = 12;
        yearly = 1;
      };
    };
  };

  # Transform a job definition into a complete borgbackup job configuration,
  # applying common settings shared across all backup jobs.
  mkBorgJob = name: job: {
    repo = mkRepoPath name;
    inherit (job)
      paths
      exclude
      startAt
      compression
      ;
    user = username;
    group = "users";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg_passphrase.path}";
    };
    persistentTimer = true;
    inhibitsSleep = true;
    inherit (job) prune;
    doInit = true;
    failOnWarnings = false;
    extraCreateArgs = [
      "--stats"
      "--exclude-caches"
      "--exclude-if-present"
      ".nobackup"
    ];
    extraPruneArgs = [
      "--stats"
      "--list"
    ];
  };

  # Helper scripts for ad-hoc browsing and recovery of borg backup archives.
  # Mounts the entire repository so all archives are visible as directories.
  borgMount = pkgs.writeShellApplication {
    name = "borg-mount";
    runtimeInputs = with pkgs; [
      borgbackup
      coreutils
      fuse
      util-linux
    ];
    text = ''
      JOB="''${1:-}"

      if [[ -z "''${JOB}" ]]; then
          echo "Usage: borg-mount <data|media>"
          echo ""
          echo "Mounts all borg backup archives for browsing and file recovery."
          echo "Available jobs: data, media"
          exit 1
      fi

      case "''${JOB}" in
          data|media)
              ;;
          *)
              echo "Error: unknown job '''''${JOB}'. Use 'data' or 'media'."
              exit 1
              ;;
      esac

      REPO="${repoPrefix}''${JOB}"
      MOUNT_POINT="''${HOME}/Backups/''${JOB}"
      export BORG_PASSCOMMAND="cat ${config.sops.secrets.borg_passphrase.path}"
      export BORG_REPO="''${REPO}"

      # Check if already mounted.
      if mountpoint -q "''${MOUNT_POINT}" 2>/dev/null; then
          echo "Already mounted at ''${MOUNT_POINT}"
          echo "To unmount: borg-umount ''${JOB}"
          exit 0
      fi

      # Create mount point if needed.
      mkdir -p "''${MOUNT_POINT}"

      # Mount the entire repo (all archives visible as directories).
      echo "Mounting ''${JOB} backups at ''${MOUNT_POINT}..."
      if borg mount "''${REPO}" "''${MOUNT_POINT}"; then
          echo ""
          echo "Mounted at: ''${MOUNT_POINT}"
          echo "Browse archives: ls ''${MOUNT_POINT}"
          echo "To unmount: borg-umount ''${JOB}"
      else
          echo "Error: failed to mount ''${JOB} backups."
          echo "Check that the repository exists at ''${REPO}"
          exit 1
      fi
    '';
  };

  borgUmount = pkgs.writeShellApplication {
    name = "borg-umount";
    runtimeInputs = with pkgs; [
      fuse
      coreutils
      util-linux
    ];
    text = ''
      JOB="''${1:-}"

      if [[ -z "''${JOB}" ]]; then
          echo "Usage: borg-umount <data|media|all>"
          echo ""
          echo "Unmounts borg backup mount points."
          exit 1
      fi

      unmount_job() {
          local job="$1"
          local mount_point="''${HOME}/Backups/''${job}"

          if mountpoint -q "''${mount_point}" 2>/dev/null; then
              fusermount -u "''${mount_point}"
              echo "Unmounted ''${mount_point}"
          else
              echo "Not mounted: ''${mount_point}"
          fi
      }

      case "''${JOB}" in
          data|media)
              unmount_job "''${JOB}"
              ;;
          all)
              unmount_job "data"
              unmount_job "media"
              ;;
          *)
              echo "Error: unknown job '''''${JOB}'. Use 'data', 'media', or 'all'."
              exit 1
              ;;
      esac
    '';
  };

  # Build a systemd service that runs borg check against a backup repository.
  # The verifyData flag controls whether the expensive --verify-data pass is
  # included; when false only lightweight index and metadata checks run.
  mkCheckService =
    name: verifyData:
    let
      kind = if verifyData then "verify" else "check";
      repoPath = mkRepoPath name;
      backupUnit = "borgbackup-job-${name}.service";
      # Prevent checks from running concurrently with the backup job or with
      # each other (check vs verify for the same repository).
      conflictUnits = [
        backupUnit
      ]
      ++ lib.optional verifyData "borgcheck-${name}.service"
      ++ lib.optional (!verifyData) "borgverify-${name}.service";
    in
    {
      description = "BorgBackup integrity check for ${name}${lib.optionalString verifyData " (full verify)"}";
      path = [
        config.services.borgbackup.package
        pkgs.coreutils
      ];
      environment = {
        BORG_REPO = repoPath;
        BORG_PASSCOMMAND = "cat ${config.sops.secrets.borg_passphrase.path}";
      };
      after = [ backupUnit ];
      conflicts = conflictUnits;
      unitConfig = {
        OnFailure = "borgnotify-${kind}-${name}.service";
        RequiresMountsFor = [ repoPath ];
      };
      serviceConfig = {
        Type = "oneshot";
        User = username;
        Group = "users";
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
        IOSchedulingPriority = 7;
        Nice = 19;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "${home}/.config/borg"
          "${home}/.cache/borg"
          repoPath
        ];
      };
      script = if verifyData then "exec borg check --verify-data" else "exec borg check";
    };

  # Build a systemd timer that triggers a borg check service on a calendar
  # schedule. Persistent ensures missed checks run on next boot.
  mkCheckTimer = name: calendar: {
    description = "Timer for BorgBackup integrity check of ${name}";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = calendar;
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Build a oneshot service that sends an email when a borg service fails.
  # Triggered via OnFailure= from check, verify, and backup job services.
  # Nullmailer delivers all mail to adminaddr, so the recipient is nominal.
  mkFailureNotify = serviceName: {
    description = "Failure notification for ${serviceName}";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      /run/wrappers/bin/sendmail -t <<EOF
      To: ${username}@${domain}
      From: borgbackup@${domain}
      Subject: [${hostname}] ${serviceName} failed

      The systemd service ${serviceName}.service on host ${hostname} has failed.

      Review the logs:
        journalctl -u ${serviceName}.service -n 50 --no-pager
      EOF
    '';
  };
in
lib.mkIf (lib.elem hostname installOn) {
  # Ensure the user's backup directory exists on the target mount.
  systemd.tmpfiles.rules = [ "d ${backupBase}/${username} 0755 ${username} users" ];

  sops.secrets.borg_passphrase = {
    sopsFile = ../../../../secrets/borg.yaml;
    key = "passphrase";
    owner = username;
    group = "users";
    mode = "0400";
  };

  # Convenience scripts for mounting and unmounting borg backup archives.
  environment.systemPackages = [
    borgMount
    borgUmount
  ];

  services.borgbackup.jobs = lib.mapAttrs mkBorgJob backupJobs;

  # Allow borgbackup services to take sleep inhibitor locks without interactive
  # authentication. The borgbackup services run as User=${username} and set
  # inhibitsSleep = true, which wraps borg in systemd-inhibit --what="sleep".
  # That takes a block lock, triggering the polkit action
  # org.freedesktop.login1.inhibit-block-sleep. The service process is not part
  # of a logind session, so polkit classifies it under "allow_any" which
  # defaults to auth_admin_keep, requiring interactive authentication that a
  # headless systemd service cannot provide.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.login1.inhibit-block-sleep" &&
          subject.user === "${username}" &&
          subject.system_unit &&
          subject.system_unit.indexOf("borgbackup-job-") === 0) {
        return polkit.Result.YES;
      }
    });
  '';

  # Lightweight integrity checks (repository index + archive metadata).
  # Run weekly on Sunday at 06:00 for data and 07:00 for media, staggered
  # to avoid both hitting disk simultaneously.
  systemd.services.borgcheck-data = mkCheckService "data" false;
  systemd.timers.borgcheck-data = mkCheckTimer "data" "Sun *-*-* 06:00:00";

  systemd.services.borgcheck-media = mkCheckService "media" false;
  systemd.timers.borgcheck-media = mkCheckTimer "media" "Sun *-*-* 07:00:00";

  # Full data verification (reads and checksums every block in the repo).
  # Run monthly on the first Sunday at 04:00 for data and 05:00 for media.
  # These are expensive operations; idle scheduling ensures they yield to
  # interactive workloads and backup jobs.
  systemd.services.borgverify-data = mkCheckService "data" true;
  systemd.timers.borgverify-data = mkCheckTimer "data" "Sun *-*-1..7 04:00:00";

  systemd.services.borgverify-media = mkCheckService "media" true;
  systemd.timers.borgverify-media = mkCheckTimer "media" "Sun *-*-1..7 05:00:00";

  # Failure notification services triggered by OnFailure= when checks or
  # backup jobs fail. Each sends an email via nullmailer's sendmail.
  systemd.services.borgnotify-check-data = mkFailureNotify "borgcheck-data";
  systemd.services.borgnotify-check-media = mkFailureNotify "borgcheck-media";
  systemd.services.borgnotify-verify-data = mkFailureNotify "borgverify-data";
  systemd.services.borgnotify-verify-media = mkFailureNotify "borgverify-media";

  # Send failure notifications when backup jobs themselves fail.
  systemd.services.borgbackup-job-data.unitConfig.OnFailure = "borgnotify-job-data.service";
  systemd.services.borgbackup-job-media.unitConfig.OnFailure = "borgnotify-job-media.service";
  systemd.services.borgnotify-job-data = mkFailureNotify "borgbackup-job-data";
  systemd.services.borgnotify-job-media = mkFailureNotify "borgbackup-job-media";
}
