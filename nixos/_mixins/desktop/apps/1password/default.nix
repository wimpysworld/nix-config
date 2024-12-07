{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor) {
  # _1password-gui is marked as broken on nix-darwin
  # - https://github.com/NixOS/nixpkgs/issues/254944
  environment.systemPackages = with pkgs; [
    _1password-cli
    (lib.mkIf (isLinux) _1password-gui)
  ];
}
