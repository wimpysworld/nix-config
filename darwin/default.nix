{
  config,
  hostname,
  inputs,
  lib,
  outputs,
  pkgs,
  platform,
  stateVersion,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  imports = [
    inputs.nix-index-database.darwinModules.nix-index
    ./${hostname}
    ./_mixins/scripts
  ];
  # ++ lib.optional isWorkstation ./_mixins/desktop;


  # Only install the docs I use
  documentation.enable = true;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.man.enable = true;

  environment = {
    systemPackages =
      with pkgs;
      [
        git
        nix-output-monitor
        nvd
        sops
      ];

    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      # Add overlays exported from other flakes:
    ];
    # Configure your nixpkgs instance
    config = {
      allowUnfree = true;
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    optimise.automatic = isLinux;
    settings = {
      auto-optimise-store = isLinux;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
      trusted-users = [
        "root"
        "${username}"
      ];
      warn-dirty = false;
    };

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";

  programs = {
    fish = {
      enable = true;
      shellAliases = {
        nano = "micro";
      };
    };
    nix-index-database.comma.enable = true;
  };
  services.nix-daemon.enable = true;
}
