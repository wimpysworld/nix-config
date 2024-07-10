{ lib, pkgs, username, ... }:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  environment.systemPackages = with pkgs; [
    _1password
    _1password-gui
    lastpass-cli
  ];
}
