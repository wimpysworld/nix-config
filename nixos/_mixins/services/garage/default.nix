{ config, hostname, lib, pkgs, ... }:
let
  installOn = [ "malak" "revan" ];
  mountPath = if hostname == "malak" then "data" else "snapshot";
in
lib.mkIf (lib.elem hostname installOn) {
  systemd.tmpfiles.rules = [
    "d /mnt/${mountPath}/ubuntu-mate/releases 0775 nobody users"
  ];
}
