{ config, lib, pkgs, ... }:
let
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf hasNvidiaGPU {
  systemd.services.netdata.path = [ pkgs.linuxPackages_latest.nvidia_x11 ];
  services.netdata.configDir."python.d.conf" = pkgs.writeText "python.d.conf" ''
    nvidia_smi: yes
  '';
}
