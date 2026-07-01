{
  config,
  inputs,
  lib,
  outputs,
  pkgs,
  ...
}:
let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  serverRegistryInputs = lib.filterAttrs (
    name: _:
    lib.elem name [
      "self"
      "nixpkgs"
      "nixpkgs-unstable"
    ]
  ) flakeInputs;
  registryInputs = if config.noughty.host.is.server then serverRegistryInputs else flakeInputs;
in
{
  # Only install the docs I use
  documentation.enable = true;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.man.enable = true;

  environment = {
    # Common packages available on all platforms.
    # Platform-specific packages are added in nixos/default.nix and darwin/default.nix.
    systemPackages = with pkgs; [
      fresh
      git
      just
      nix-output-monitor
      nvd
      sops
    ];

    variables = {
      EDITOR = "fresh";
      GIT_EDITOR = "fresh";
      SUDO_EDITOR = "fresh";
      SYSTEMD_EDITOR = "fresh";
      VISUAL = "fresh";
    };
  };

  nixpkgs = {
    overlays = [
      # Overlays defined via overlays/default.nix and pkgs/default.nix
      outputs.overlays.localPackages
      outputs.overlays.modifiedPackages
      outputs.overlays.unstablePackages
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
    };
    # Disable channels
    channel.enable = false;
    # Make flake registry and nix path match the selected input set.
    registry = lib.mapAttrs (_: flake: { inherit flake; }) registryInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") registryInputs;
  };

  programs = {
    fish.enable = true;
    nix-index-database.comma.enable = false;
  };
}
