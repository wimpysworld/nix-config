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

  # Pre-start script that configures CID, tags, and BPF backend before
  # launching the daemon. Running in ExecStartPre means failures are visible
  # in systemd logs and prevent the service from starting in a broken state.
  # The -f flag forces falconctl to overwrite existing values, avoiding silent
  # failures when a previous (possibly empty or corrupt) value is present.
  falconStartPre = pkgs.writeShellScript "falcon-start-pre" ''
    set -euo pipefail

    # Ensure /var/log/falconctl.log is a real file, not a symlink.
    # The Falcon install script sometimes creates a symlink to /dev/stdout
    # which falconctl cannot write to (errno 6: ENXIO).
    if [ -L /var/log/falconctl.log ]; then
      rm -f /var/log/falconctl.log
      touch /var/log/falconctl.log
      chmod 0640 /var/log/falconctl.log
    elif [ ! -f /var/log/falconctl.log ]; then
      touch /var/log/falconctl.log
      chmod 0640 /var/log/falconctl.log
    fi

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
    # The log file /var/log/falconctl.log is managed by ExecStartPre to ensure
    # it is always a real file (not a symlink) when the service starts.
    systemd.tmpfiles.rules = [
      "d ${installDir} 0750 root root - -"
    ];

    # The falcon-sensor systemd service.
    # falcond is a forking daemon that manages the sensor process.
    systemd.services.falcon-sensor = {
      description = "CrowdStrike Falcon Sensor";
      after = [
        "local-fs.target"
        "network.target"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];

      # Ensure the sensor shuts down cleanly before the system powers off.
      conflicts = [ "shutdown.target" ];
      before = [ "shutdown.target" ];

      # Only start if the sensor binaries have been bootstrapped.
      unitConfig = {
        ConditionPathExists = "${installDir}/falcond";
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
        # The Falcon binaries are patched with patchelf to use the Nix glibc
        # interpreter, but the linker still needs to find shared libraries
        # (libssl, libnl, libz, etc.) which nix-ld provides at this path.
        Environment = [
          "LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib"
        ];
        ReadWritePaths = [
          installDir
          "/var/log"
          "/run/secrets"
        ];
      };
    };
  };
}
