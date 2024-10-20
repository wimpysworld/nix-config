{ config, hostname, lib, tailNet, ... }:
let
  basePath = "/syncthing";
  # Only enables caddy if tailscale is enabled or the host is Malak
  useCaddy = if (config.services.tailscale.enable || lib.elem hostname [ "malak" ])
    then true else false;
in
{
  services = {
    caddy = {
      enable = useCaddy;
      # Reverse proxy syncthing; which is configured/enabled via Home Manager
      virtualHosts."${hostname}.${tailNet}".extraConfig = lib.mkIf
        config.services.tailscale.enable
        ''
          redir ${basePath} ${basePath}/
          handle_path ${basePath}/* {
            reverse_proxy localhost:8384 {
              header_up Host localhost
            }
          }
        '';
    };
  };
}
