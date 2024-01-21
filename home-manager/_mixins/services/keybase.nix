{ config, desktop, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    keybase
  ] ++ lib.optionals (desktop != null) [
    keybase-gui
  ];
  services = {
    kbfs = {
      enable = isLinux;
      extraFlags = [ "-label ${username}-KBFS" "-mode=minimal" ];
      mountPoint = "Keybase";
    };
    keybase = {
      enable = isLinux;
    };
  };
  systemd.user.services = lib.mkIf (desktop != null) {
    keybase-gui = {
      Unit = {
        Description = "Keybase GUI";
      };
      Service = {
        ExecStart = "${pkgs.keybase-gui}/bin/keybase-gui";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
