{ config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home = {
    file = {
      "${config.xdg.configHome}/sakura/sakura.conf".text = builtins.readFile ./sakura.conf;
    };
    packages = with pkgs; [
      sakura
    ];
  };
}
