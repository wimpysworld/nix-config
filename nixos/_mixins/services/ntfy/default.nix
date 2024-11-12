{ config, hostname, lib, tailNet, ... }:
let
  installOn = [ "malak" ];
in
lib.mkIf (lib.elem hostname installOn) {
  services = {
    # https://docs.ntfy.sh/config/#__tabbed_11_4
    # https://blog.alexsguardian.net/posts/2023/09/12/selfhosting-ntfy/
    caddy = {
      virtualHosts."ntfy.wimpys.world" = {
        extraConfig = lib.mkIf config.services.ntfy-sh.enable ''
          reverse_proxy localhost:2586
          @httpget {
            protocol http
            method GET
            path_regexp ^/([-_a-z0-9]{0,64}$|docs/|static/)
          }
          redir @httpget https://{host}{uri}
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/ntfy.log
        '';
      };
    };
    ntfy-sh = {
      enable = true;
      settings = {
        attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
        auth-default-access = "deny-all";
        auth-file = "/var/lib/ntfy-sh/user.db";
        base-url = "https://ntfy.wimpys.world";
        behind-proxy = true;
        cache-file = "/var/lib/ntfy-sh/cache-file.db";
        enable-login = true;
        #https://docs.ntfy.sh/config/#ios-instant-notifications
        upstream-base-url = "https://ntfy.sh";
      };
    };
  };
}
