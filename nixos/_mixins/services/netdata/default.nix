{
  config,
  hostname,
  lib,
  pkgs,
  tailNet,
  ...
}:
let
  basePath = "/netdata";
  installOn = [ "malak" "revan" ];
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf (lib.elem config.networking.hostName installOn) {
  services = {
    # Reverse proxy netdata if Tailscale is enabled.
    caddy.virtualHosts."${hostname}.${tailNet}".extraConfig = lib.mkIf
      (config.services.netdata.enable && config.services.tailscale.enable)
      ''
        redir ${basePath} ${basePath}/
        reverse_proxy ${basePath}/* localhost:19999
      '';
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
  systemd.services.netdata.path = lib.optionals hasNvidiaGPU [ pkgs.linuxPackages_6_12.nvidia_x11 ];
}
