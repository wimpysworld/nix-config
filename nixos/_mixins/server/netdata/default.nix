{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  basePath = "/netdata";
in
lib.mkIf host.is.server {
  services = {
    # Reverse proxy netdata if Tailscale is enabled.
    caddy.virtualHosts."${host.name}.${config.noughty.network.tailNet}".extraConfig =
      lib.mkIf (config.services.netdata.enable && config.services.tailscale.enable)
        ''
          redir ${basePath} ${basePath}/
          reverse_proxy ${basePath}/* localhost:19999
        '';
    netdata = {
      # Enable the Nvidia plugin for Netdata if an Nvidia GPU is present.
      configDir = lib.mkIf host.gpu.hasNvidia {
        "python.d.conf" = pkgs.writeText "python.d.conf" ''
          nvidia_smi: yes
        '';
      };
      enable = true;
      enableAnalyticsReporting = false;
      package = pkgs.netdata;
    };
  };
  # Enable the Nvidia plugin for Netdata if an Nvidia GPU is present.
  systemd.services.netdata.path = lib.optionals host.gpu.hasNvidia [
    config.boot.kernelPackages.nvidia_x11
  ];
}
