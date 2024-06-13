{ hostname, lib, pkgs, ... }:
{
  services = {
    caddy = {
      enable = lib.mkForce true;
      extraConfig = ''
          redir /netdata /netdata/
          handle_path /netdata/* {
            reverse_proxy localhost:19999
          }
          redir /syncthing /syncthing/
          handle_path /syncthing/* {
            reverse_proxy localhost:8384 {
              header_up Host {upstream_hostport}
            }
          }
          reverse_proxy localhost:8082
        }
      '';
    };
  };
}
