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
  # Automates the bootstrap and update process for CrowdStrike Falcon on NixOS.
  # Downloads the sensor RPM, extracts it, copies binaries to /opt/CrowdStrike/,
  # and patches all ELF binaries with the NixOS glibc interpreter.
  # See NixOS-Falcon-Sensor.md for full documentation.
  falconSensorInstall = pkgs.writeShellApplication {
    name = "falcon-sensor-install";
    runtimeInputs = with pkgs; [
      coreutils
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

  # CrowdStrike Falcon sensor for security monitoring and intrusion detection.
  # The NixOS module (modules/nixos/falcon-sensor.nix) manages the systemd service
  # and CID/BPF configuration. The sensor binaries are bootstrapped to
  # /opt/CrowdStrike/ using falcon-sensor-install. See NixOS-Falcon-Sensor.md.
  services.falcon-sensor = {
    enable = true;
    cidFile = config.sops.secrets.falcon-cid.path;
    traceLevel = "err";
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
