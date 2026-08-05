# Policy and compliance agents.
# - Kolide: device trust and compliance monitoring
#   https://github.com/kolide/nix-agent
# - CrowdStrike Falcon: security monitoring and intrusion detection
#   See NixOS-Falcon-Sensor.md for bootstrap instructions.
{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;

  # Logging wrapper around xdg-open for the Kolide desktop process. Tray
  # menu clicks run xdg-open with output discarded and the exit status
  # unchecked (kolide/launcher issue 2430), so this wrapper logs every
  # invocation to a private log in XDG_RUNTIME_DIR (falling back to /tmp,
  # created 0600) before delegating to the real
  # xdg-open from xdg-utils. The host desktop name is baked in at build
  # time because only PATH reaches the desktop process.
  kolideXdgOpen = pkgs.writeShellApplication {
    name = "xdg-open";
    runtimeInputs = with pkgs; [
      coreutils
      dbus
      xdg-utils
    ];
    runtimeEnv = {
      KOLIDE_XDG_CURRENT_DESKTOP =
        {
          hyprland = "Hyprland";
        }
        .${toString config.noughty.host.desktop} or "";
    };
    text = builtins.readFile ./kolide-xdg-open.sh;
  };

  # Automates the bootstrap and update process for CrowdStrike Falcon on NixOS.
  # Downloads the sensor RPM, extracts it, copies binaries to /opt/CrowdStrike/,
  # and patches all ELF binaries with the NixOS glibc interpreter.
  # See NixOS-Falcon-Sensor.md for full documentation.
  falconSensorInstall = pkgs.writeShellApplication {
    name = "falcon-sensor-install";
    runtimeInputs = with pkgs; [
      coreutils
      cpio
      gh
      gnugrep
      jq
      patchelf
      rpm
    ];
    text = builtins.readFile ./falcon-sensor-install.sh;
  };

  # Quick health check for the CrowdStrike Falcon sensor.
  # Reports service status, CID, RFM state, backend, and cloud connectivity.
  falconSensorCheck = pkgs.writeShellApplication {
    name = "falcon-sensor-check";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = builtins.readFile ./falcon-sensor-check.sh;
  };
in
lib.mkIf (noughtyLib.hostHasTag "policy") {

  environment.systemPackages = [
    falconSensorCheck
    falconSensorInstall
  ];

  # Kolide launcher agent for device trust and compliance monitoring.
  # The NixOS module (imported via inputs.kolide-launcher.nixosModules.kolide-launcher
  # in nixos/default.nix) handles the package, systemd service, and tmpfiles rules.
  # The enrollment secret is deployed via sops-nix below.
  services.kolide-launcher = {
    enable = true;
  };

  # The launcher spawns the per-user "launcher desktop" process with a
  # fresh environment and copies only PATH from this unit (desktopCommand
  # in ee/desktop/runner/runner.go), so setting any other variable here
  # has no effect. Everything the AppIndicator needs must therefore
  # resolve via PATH: the logging xdg-open wrapper comes first, then the
  # system profiles, then the per-user Home Manager profiles so browsers
  # referenced by .desktop Exec entries are found, then the unit's own
  # path list (xdg-utils and glib).
  systemd.services.kolide-launcher = {
    path = [
      pkgs.xdg-utils
      pkgs.glib
    ];
    serviceConfig = {
      Environment = lib.mkForce "PATH=${kolideXdgOpen}/bin:/run/wrappers/bin:/bin:/sbin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${username}/bin:/home/${username}/.nix-profile/bin:${config.systemd.services.kolide-launcher.environment.PATH}";
      # Give Kolide longer to flush osquery state on shutdown. The default
      # TimeoutStopSec of 90 seconds is occasionally insufficient for
      # long-running launcher processes on busy workstations and results
      # in a SIGKILL of launcher and osqueryd, leaving event-store writes
      # half-flushed. 180 seconds gives generous headroom without
      # delaying shutdown meaningfully.
      TimeoutStopSec = lib.mkDefault 180;
    };
  };

  # CrowdStrike Falcon sensor for security monitoring and intrusion detection.
  # The NixOS module (modules/nixos/falcon-sensor.nix) manages the systemd service
  # and CID/BPF configuration. The sensor binaries are bootstrapped to
  # /opt/CrowdStrike/ using falcon-sensor-install. See NixOS-Falcon-Sensor.md.
  services.falcon-sensor = {
    enable = true;
    cidFile = config.sops.secrets.falcon-cid.path;
    traceLevel = "err";
    # Silence repeated "Could not retrieve DisableProxy value: c0000225"
    # log noise on hosts with no proxy in use.
    disableAutoProxyDetection = true;
  };

  # Deploy secrets for policy/compliance agents via sops-nix.
  # See NixOS-Kolide.md and NixOS-Falcon-Sensor.md for obtaining these secrets.
  sops = {
    secrets = {
      kolide = {
        mode = "0600";
        path = "/etc/kolide-k2/secret";
        sopsFile = ../../../secrets/policy.yaml;
      };
      falcon-cid = {
        mode = "0600";
        sopsFile = ../../../secrets/policy.yaml;
      };
      falcon-repo = {
        mode = "0600";
        sopsFile = ../../../secrets/policy.yaml;
      };
    };
  };
}
