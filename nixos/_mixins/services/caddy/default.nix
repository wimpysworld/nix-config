{ config, hostname, lib, pkgs, tailNet, ... }:
let
  basePath = "/syncthing";
  # Only enables caddy if tailscale is enabled or the host is Malak
  useCaddy = if (config.services.tailscale.enable || lib.elem hostname [ "malak" ])
    then true else false;
in
{
  environment.systemPackages = with pkgs; [ custom-caddy ];
  services = {
    caddy = {
      enable = useCaddy;
      package = pkgs.custom-caddy;
      # Reverse proxy syncthing; which is configured/enabled via Home Manager
      virtualHosts."${hostname}.${tailNet}" = lib.mkIf config.services.tailscale.enable
      {
        extraConfig = ''
            redir ${basePath} ${basePath}/
            handle_path ${basePath}/* {
              reverse_proxy localhost:8384 {
                header_up Host localhost
              }
            }
          '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/tailscale.log
        '';
      };
    };
  };
}
