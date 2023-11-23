{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  # https://localsend.org/
  home.packages = with pkgs; [
    localsend
  ];

  systemd.user.services = lib.mkIf isLinux {
    localsend = {
      Unit = {
        Description = "LocalSend";
      };
      Service = {
        ExecStart = "${pkgs.localsend}/bin/localsend";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
