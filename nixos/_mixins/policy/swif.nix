# Swif.ai mobile device management (MDM) agent. See NixOS-Swif.md.
{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  # Swif does not support NixOS on ARM. The platform comes from noughty, not
  # pkgs, because the gated vendor files set nixpkgs.config and reading pkgs
  # here would recurse.
  enableSwif =
    noughtyLib.hostHasTag "cg"
    && noughtyLib.isHost [ "ravi" ]
    && config.noughty.host.platform == "x86_64-linux";

  # The agent writes generated policy modules to <nixRootPath>/swifteam/.
  # Nothing imports them. See NixOS-Swif.md for why this is not /etc/nixos.
  nixRootPath = "/etc/swif";

  # Several vendor files set configuration without checking
  # services.swifteam.enable, which would change every host that imports
  # them. Wrap each file so that it applies only when the service is
  # enabled. The wrapper names config, lib and pkgs because the module
  # system passes only the arguments that a module function names.
  gateVendorModule =
    path:
    {
      config,
      lib,
      pkgs,
      ...
    }@args:
    let
      module = import path;
      result = if lib.isFunction module then module args else module;
    in
    {
      _file = path;
      config = lib.mkIf config.services.swifteam.enable (result.config or result);
    };

  # options.nix only declares options, so it stays unwrapped.
  vendorImports = (import "${inputs.swifteam}/default.nix").imports;

  swifSecrets = [
    "swif-teamid"
    "swif-firstname"
    "swif-surname"
    "swif-email"
  ];

  # The same pinned binary that the vendor installer.nix fetches. The vendor
  # derivation is private to that file, so it is rebuilt here from the
  # vendor's own version.nix.
  installerPin =
    (import "${inputs.swifteam}/version.nix").${pkgs.stdenv.hostPlatform.system}.installer;
  swifInstallerSrc = pkgs.fetchurl {
    inherit (installerPin) url;
    sha256 = installerPin.hash;
  };
  swifInstaller = pkgs.runCommand "swif-installer" { } ''
    install -Dm755 ${swifInstallerSrc} $out/bin/SwifInstaller
  '';

  # Runs the vendor installer with identity values read from systemd
  # credentials, so that they never enter the Nix store.
  swifInstall = pkgs.writeShellApplication {
    name = "swif-install";
    runtimeInputs = [
      pkgs.coreutils
      swifInstaller
    ];
    runtimeEnv = {
      SWIF_NIX_ROOT_PATH = config.services.swifteam.nixRootPath;
    };
    text = builtins.readFile ./swif-install.sh;
  };

  # Read-only health check for enrolment, services and generated files.
  swifAgentCheck = pkgs.writeShellApplication {
    name = "swif-agent-check";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      getent
      gnugrep
      systemd
    ];
    runtimeEnv = {
      SWIF_NIX_ROOT_PATH = config.services.swifteam.nixRootPath;
    };
    text = builtins.readFile ./swif-agent-check.sh;
  };
in
{
  imports = map (
    path: if baseNameOf path == "options.nix" then path else gateVendorModule path
  ) vendorImports;

  config = lib.mkIf enableSwif {
    environment.systemPackages = [ swifAgentCheck ];

    # The four identity options stay at their empty defaults. The vendor
    # installer script bakes them into the Nix store, so swif-install
    # replaces it and reads the values from sops through LoadCredential.
    services.swifteam = {
      enable = true;
      inherit nixRootPath;
    };

    systemd = {
      services.swif-agent-installer.serviceConfig = {
        ExecStart = lib.mkForce (lib.getExe swifInstall);
        LoadCredential = map (name: "${name}:${config.sops.secrets.${name}.path}") swifSecrets;
      };

      # Root only, so that local users cannot read the generated policies.
      tmpfiles.rules = [ "d ${nixRootPath} 0700 root root - -" ];
    };

    # Deploy the enrolment identity via sops-nix. See NixOS-Swif.md.
    sops.secrets = lib.genAttrs swifSecrets (_: {
      mode = "0600";
      sopsFile = ../../../secrets/policy.yaml;
    });
  };
}
