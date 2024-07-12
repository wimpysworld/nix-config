{
  config,
  lib,
  pkgs,
  ...
}:
let
  installOn = [ "revan" ];
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf (lib.elem config.networking.hostName installOn) {
  services = {
    netdata = {
      # Enable the Nvidia plugin for Netdata if an Nvidia GPU is present
      configDir = lib.mkIf hasNvidiaGPU {
        "python.d.conf" = pkgs.writeText "python.d.conf" ''
          nvidia_smi: yes
        '';
      };
      enable = true;
      enableAnalyticsReporting = false;
      package = pkgs.netdata;
    };
  };
  # Enable the Nvidia plugin for Netdata if an Nvidia GPU is present
  systemd.services.netdata.path = lib.optionals hasNvidiaGPU [ pkgs.linuxPackages_latest.nvidia_x11 ];
}
