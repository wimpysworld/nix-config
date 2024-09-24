{ config, lib, pkgs, username, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils-full
      curl
      gnugrep
      gnutar
    ];
    text = builtins.readFile ./${name}.sh;
  };
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home = {
    file = {
      "${config.home.homeDirectory}/Apps/Defold/distrobox.ini".text = builtins.readFile ./distrobox.ini;
    };
    packages = with pkgs; [ shellApplication ];
  };
  systemd.user.tmpfiles.rules = [
    "d ${config.home.homeDirectory}/Apps/Defold 0755 ${username} users - -"
  ];
}
