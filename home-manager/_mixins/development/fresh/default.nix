{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;

  catppuccinFresh = pkgs.fetchFromGitHub {
    owner = "milon";
    repo = "catppuccin-fresh";
    rev = "58093e748cbf90e742c913f469fb20dd6aacba2b";
    hash = "sha256-C98XNiUtT0/cAbGzjaX+i1vlnFLp1Pf2UpEmk4Qsuoc=";
  };
in
lib.mkIf host.is.workstation {
  home.packages = [
    inputs.fresh.packages.${system}.fresh
  ];

  xdg.configFile = {
    "fresh/config.json".text = lib.mkDefault (
      builtins.toJSON {
        theme = "catppuccin-mocha.json";
      }
    );

    "fresh/themes/catppuccin-frappe.json".source = "${catppuccinFresh}/catppuccin-frappe.json";
    "fresh/themes/catppuccin-latte.json".source = "${catppuccinFresh}/catppuccin-latte.json";
    "fresh/themes/catppuccin-macchiato.json".source = "${catppuccinFresh}/catppuccin-macchiato.json";
    "fresh/themes/catppuccin-mocha.json".source = "${catppuccinFresh}/catppuccin-mocha.json";
  };
}
