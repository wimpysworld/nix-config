{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  nixos-needsreboot = pkgs.writeShellApplication {
    name = "nixos-needsreboot";
    runtimeInputs = with pkgs; [ coreutils ];
    text = builtins.readFile ./nixos-needsreboot.sh;
  };
in
{
  environment.systemPackages = lib.optionals (host.is.linux && !host.is.iso) [
    nixos-needsreboot
  ];
}
