# CrowdStrike Falcon sensor NixOS module.
# Falcon is a proprietary binary that cannot be packaged declaratively.
# The sensor binaries are bootstrapped to /opt/CrowdStrike/ using the
# falcon-sensor-install script before enabling this module.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;
  cfg = config.services.falcon-sensor;
  installDir = "/opt/CrowdStrike";
  stageDir = "/opt/CrowdStrike.staged";

  # Applies a staged sensor update at boot, before falcon-sensor starts and
  # arms tamper protection. falcon-sensor-install prepares the tree; it
  # stages automatically whenever the sensor is running.
  # The copy overlays files into the live directory instead of replacing it,
  # so runtime state such as falconstore (the agent ID) survives updates.
  # The staging directory is removed last: an interrupted apply leaves the
  # completion marker in place, so the next boot retries the whole copy.
  falconApplyStaged = pkgs.writeShellScript "falcon-apply-staged" ''
    set -euo pipefail
    if pgrep -x falcond > /dev/null; then
      echo "Sensor is running; deferring the staged update to the next boot."
      exit 0
    fi
    STAGED_VERSION="$(cat "${stageDir}/.staged-version" 2>/dev/null || echo unknown)"
    echo "Applying staged Falcon sensor update (version $STAGED_VERSION)..."
    mkdir -p "${installDir}"
    cp -a "${stageDir}/." "${installDir}/"
    rm -f "${installDir}/.stage-complete" "${installDir}/.staged-version"
    chown -R root:root "${installDir}"
    chmod -R 0750 "${installDir}"
    rm -rf "${stageDir}"
    echo "Staged Falcon sensor update applied."
  '';

  # Pre-start script that configures CID, tags, and BPF backend before
  # launching the daemon. Running in ExecStartPre means failures are visible
  # in systemd logs and prevent the service from starting in a broken state.
  # The -f flag forces falconctl to overwrite existing values, avoiding silent
  # failures when a previous (possibly empty or corrupt) value is present.
  falconStartPre = pkgs.writeShellScript "falcon-start-pre" ''
    set -euo pipefail

    # /var/log/falconctl.log is owned by Falcon's own startup logic, which
    # recreates it as a symlink to /dev/stdout on every service start.
    # systemd captures that output to the journal, so falconctl messages
    # remain observable via `journalctl -u falcon-sensor`. We deliberately
    # do not try to manage this file here: previous attempts to convert it
    # to a regular file were silently overwritten by Falcon on every boot,
    # and each ExecStartPre falconctl invocation logged ENXIO without any
    # observable impact on sensor health.

    ${optionalString (cfg.cidFile != null) ''
      if [ -f "${cfg.cidFile}" ]; then
        CID="$(tr -d '[:space:]' < "${cfg.cidFile}")"
        if [ -n "$CID" ]; then
          echo "Setting CID..."
          "${installDir}/falconctl" -s --cid="$CID" -f
        else
          echo "WARNING: CID file exists but is empty: ${cfg.cidFile}"
        fi
      else
        echo "WARNING: CID file not found: ${cfg.cidFile}"
      fi
    ''}
    ${optionalString (cfg.tags != [ ]) ''
      echo "Setting tags..."
      "${installDir}/falconctl" -s --tags="${concatStringsSep "," cfg.tags}" -f
    ''}
    ${optionalString (cfg.provisioningTokenFile != null) ''
      if [ -f "${cfg.provisioningTokenFile}" ]; then
        TOKEN="$(tr -d '[:space:]' < "${cfg.provisioningTokenFile}")"
        if [ -n "$TOKEN" ]; then
          echo "Setting provisioning token..."
          "${installDir}/falconctl" -s --provisioning-token="$TOKEN" -f
        else
          echo "WARNING: Provisioning token file exists but is empty: ${cfg.provisioningTokenFile}"
        fi
      else
        echo "WARNING: Provisioning token file not found: ${cfg.provisioningTokenFile}"
      fi
    ''}
    ${optionalString (cfg.traceLevel != null) ''
      echo "Setting trace level to ${cfg.traceLevel}..."
      "${installDir}/falconctl" -s --trace="${cfg.traceLevel}" -f
    ''}
    ${optionalString cfg.disableAutoProxyDetection ''
      echo "Disabling auto proxy detection..."
      "${installDir}/falconctl" -s --apd=true -f
    ''}
    echo "Setting backend to bpf..."
    "${installDir}/falconctl" -s --backend=bpf -f
    # Verify CID is set; informational only - do not block startup.
    "${installDir}/falconctl" -g --cid || true
  '';
in
{
  options.services.falcon-sensor = {
    enable = mkEnableOption "CrowdStrike Falcon sensor";

    cidFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the CrowdStrike Customer ID (CID).
        Typically managed by sops-nix. The file should contain only the
        CID string (e.g. XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-XX).
      '';
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Sensor grouping tags for the CrowdStrike console.
        Applied via falconctl -s --tags=.
      '';
    };

    traceLevel = mkOption {
      type = types.nullOr (
        types.enum [
          "none"
          "err"
          "warn"
          "info"
          "debug"
        ]
      );
      default = null;
      description = ''
        Falcon sensor trace/logging verbosity level.
        When null, the sensor's built-in default is used.
      '';
    };

    provisioningTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing a provisioning token for sensor registration.
        Required in environments that mandate tokens for new sensor enrolment.
        Typically managed by sops-nix.
      '';
    };

    disableAutoProxyDetection = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to disable Falcon's auto proxy detection.
        When true, falconctl is invoked with --apd=true during
        ExecStartPre, which suppresses repeated "Could not retrieve
        DisableProxy value: c0000225" log noise on hosts with no proxy.
        Falcon falls back to direct connection regardless; this only
        silences the spurious error logging.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Falcon's prebuilt binaries need a standard dynamic linker and libraries.
    # nix-ld provides these without polluting the Nix store.
    # openssl and zlib are included in the nix-ld base libraries, but libnl
    # is not; Falcon needs it for network-level telemetry.
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        libnl
      ];
    };

    # Ensure /opt/CrowdStrike persists across reboots.
    # Permissions are 0750 - non-root users have no reason to access this.
    # /var/log/falconctl.log is intentionally not managed here: Falcon
    # recreates it as a symlink to /dev/stdout at every service start,
    # and journald captures that output via systemd stdout capture.
    systemd.tmpfiles.rules = [
      "d ${installDir} 0750 root root - -"
    ];

    # Log rotation for Falcon's sensor logs.
    # The vendor package ships a logrotate rule that reopens the log with
    # "pkill -HUP falcon-sensor", but sensor 7.38+ tamper protection
    # blocks external signals while the sensor is armed, so that pattern
    # is not reliable here. Restarting a security sensor purely to
    # rotate its logs would create blind windows in EDR coverage and is
    # unacceptable. copytruncate sidesteps this: logrotate copies the
    # current file then truncates the original in place, so the daemon's
    # open file descriptor keeps writing to the same inode.
    # falconctl.log is deliberately excluded: it is managed by
    # ExecStartPre (which recreates it as a real file each start), and on
    # first boot it is a symlink to /dev/stdout so its output already
    # flows to journald via systemd. Rotating it would fight ExecStartPre.
    services.logrotate.settings."falcon-sensor" = lib.mkDefault {
      files = [
        "/var/log/falcon-sensor.log"
        "/var/log/falcon-libbpf.log"
        "/var/log/falcond.log"
      ];
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      # Required: the daemon holds the file descriptor open and offers no
      # reopen signal, so we copy then truncate in place rather than
      # rename + signal.
      copytruncate = true;
      # Catch runaway growth (the main sensor log has hit 15 GB in the
      # wild) by rotating mid-day if a single file balloons past 100 MB.
      maxsize = "100M";
      # Falcon writes its logs as 0640 root:root.
      su = "root root";
    };

    # Applies a staged sensor update at boot, before the sensor starts and
    # arms tamper protection. Skipped unless falcon-sensor-install left a
    # complete stage behind. Never started by nixos-rebuild switch:
    # applying a stage over a running, armed sensor would fail, so the
    # apply happens only at boot.
    systemd.services.falcon-sensor-staged-update = {
      description = "Apply staged CrowdStrike Falcon sensor update";
      before = [ "falcon-sensor.service" ];
      wantedBy = [ "multi-user.target" ];
      restartIfChanged = false;
      stopIfChanged = false;
      unitConfig = {
        ConditionPathExists = "${stageDir}/.stage-complete";
      };
      path = [
        pkgs.coreutils
        pkgs.procps
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = falconApplyStaged;
      };
    };

    # The falcon-sensor systemd service.
    # falcond is a forking daemon that manages the sensor process.
    systemd.services.falcon-sensor = {
      description = "CrowdStrike Falcon Sensor";
      after = [
        "local-fs.target"
        "network.target"
        "sops-nix.service"
        "falcon-sensor-staged-update.service"
      ];
      wants = [ "falcon-sensor-staged-update.service" ];
      wantedBy = [ "multi-user.target" ];

      # Ensure the sensor shuts down cleanly before the system powers off.
      conflicts = [ "shutdown.target" ];
      before = [ "shutdown.target" ];

      # Sensor 7.38+ arms maintenance (tamper) protection while it runs:
      # kill signals are blocked at kernel level, even from systemd as
      # PID 1, and /opt/CrowdStrike is write-protected, even against root.
      # A unit restart therefore cannot kill the old instance; the new
      # falcond spawns falcon-sensor children that exit with status 85
      # until "Respawn count exceeded maximum", and the unit ends up dead
      # while the original sensor keeps running detached from systemd.
      # Never restart or stop this unit on nixos-rebuild switch; unit
      # changes take effect at the next reboot, which also avoids gaps in
      # EDR telemetry.
      restartIfChanged = false;
      stopIfChanged = false;

      # Only start if the sensor binaries have been bootstrapped.
      unitConfig = {
        ConditionPathExists = "${installDir}/falcond";
        # When startup genuinely fails, stop retrying after five attempts
        # in ten minutes instead of looping indefinitely. A restart loop of
        # 461 attempts was observed while an armed orphan instance blocked
        # startup.
        StartLimitIntervalSec = 600;
        StartLimitBurst = 5;
      };

      serviceConfig = {
        ExecStartPre = [ falconStartPre ];
        ExecStart = "${installDir}/falcond";
        Type = "forking";
        PIDFile = "/run/falcond.pid";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "60s";
        KillMode = "control-group";
        KillSignal = "SIGTERM";
        # The sensor moves its processes into a private sensor.falcon
        # sub-cgroup. Delegation matches the vendor 7.38 unit and stops
        # systemd from managing inside the delegated subtree.
        Delegate = true;
        # LD_LIBRARY_PATH is for our own Falcon binaries, which are patched
        # with patchelf to use the Nix glibc interpreter and rely on nix-ld's
        # library directory to resolve shared objects (libssl, libnl, libz,
        # etc.) at runtime.
        #
        # NIX_LD and NIX_LD_LIBRARY_PATH cover any child processes falcond
        # spawns from cloud-staged sensor binaries. Those binaries are not
        # patched by us and still reference the generic
        # /lib64/ld-linux-x86-64.so.2 interpreter, which on NixOS is the
        # nix-ld shim; without these variables in the service environment
        # the shim has nothing to dispatch to and execs fail with
        # STATUS_GENERIC_COMMAND_FAILED (c0150026). Values come from the
        # programs.nix-ld module so we track the current system symlink
        # rather than hardcoding a store path.
        Environment = [
          "LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib"
          "NIX_LD=${config.environment.variables.NIX_LD}"
          "NIX_LD_LIBRARY_PATH=${config.environment.variables.NIX_LD_LIBRARY_PATH}"
        ];
        ReadWritePaths = [
          installDir
          "/var/log"
          "/run/secrets"
        ];
        # Prevent the sensor from consuming swap. A swapped-out security
        # sensor is functionally dead; force pressure to manifest as
        # throttling or OOM instead.
        MemorySwapMax = "0";
        # If the sensor is OOM-killed, stop the unit cleanly. Combined
        # with Restart=on-failure, it will restart automatically.
        OOMPolicy = "stop";
        # Deprioritise the sensor when systemd-oomd selects candidates
        # for proactive killing under system-wide memory pressure.
        ManagedOOMPreference = "avoid";
        # CPU scheduling: lower priority than default processes.
        # batch optimises for throughput over latency, reducing context
        # switches. Nice 5 and CPUWeight 80 yield to interactive work
        # under contention without starving event processing.
        Nice = 5;
        CPUSchedulingPolicy = "batch";
        CPUWeight = 80;
        # IO scheduling: slightly yield to user workloads.
        IOWeight = 80;
      };
    };
  };
}
