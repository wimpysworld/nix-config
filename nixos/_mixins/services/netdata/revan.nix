{ config, lib, pkgs, ... }:
let
  hasNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf hasNvidia {
  systemd.services.netdata.path = [ pkgs.linuxPackages_latest.nvidia_x11 ];
  services.netdata.configDir."python.d.conf" = pkgs.writeText "python.d.conf" ''
    nvidia_smi: yes
  '';
}
