{
  config,
  hostname,
  lib,
  pkgs,
  tailNet,
  username,
  ...
}:
let
  basePath = "/syncthing";
  # Only enables caddy if tailscale is enabled or the host is Malak
  useCaddy =
    if (config.services.tailscale.enable || lib.elem hostname [ "malak" ]) then true else false;
in
{
  environment = {
    shellAliases = {
      caddy-log = "journalctl _SYSTEMD_UNIT=caddy.service";
    };
    systemPackages = with pkgs; [ caddy ];
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
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/WeidiDeng/caddy-cloudflare-ip@v0.0.0-20231130002422-f53b62aa13cb"
        ];
        hash = "sha256-UhQOGV0149dK4u9mr449aohfG3KKwSDRW9WrvT0uOKI=";
      };
      # Reverse proxy syncthing; which is configured/enabled via Home Manager
      virtualHosts."${hostname}.${tailNet}" = lib.mkIf config.services.tailscale.enable {
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
