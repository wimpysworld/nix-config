{ config, hostname, lib, pkgs, tailNet, username, ... }:
let
  basePath = "/syncthing";
  # Only enables caddy if tailscale is enabled or the host is Malak
  useCaddy = if (config.services.tailscale.enable || lib.elem hostname [ "malak" ])
    then true else false;
in
{
  environment = {
    shellAliases = {
      caddy-log = "journalctl _SYSTEMD_UNIT=caddy.service";
    };
    systemPackages = with pkgs; [ custom-caddy ];
  };
  services = {
    caddy = {
      enable = useCaddy;
      email = "${username}@wimpysworld.com";
      globalConfig = ''
        servers {
          trusted_proxies cloudflare {
            interval 12h
            timeout 15s
          }
        }
      '';
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
