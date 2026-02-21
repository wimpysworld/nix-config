{
  config,
  inputs,
  lib,
  outputs,
  pkgs,
  ...
}:
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
      git
      just
      micro
      nix-output-monitor
      sops
    ];

    variables = {
      EDITOR = "micro";
      VISUAL = "micro";
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

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;
        # Allow wheel users to set client-side Nix options (e.g. netrc-file
        # for FlakeHub Cache authentication via fh apply).
        trusted-users = [
          "root"
          "@wheel"
        ];
      };
      # Disable channels
      channel.enable = false;
      # Make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
    };

  programs = {
    fish.enable = true;
    nix-index-database.comma.enable = false;
  };
}
