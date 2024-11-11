{ config, hostname, lib, username, ... }:
let
  installOn = [ "malak" ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      gotosocial-log = "journalctl _SYSTEMD_UNIT=gotosocial.service";
    };
  };
  sops = {
    secrets = {
      gotosocial-env = {
        group = "gotosocial";
        mode = "0644";
        owner = "gotosocial";
        path = "/mnt/data/gotosocial/secrets.env";
        sopsFile = ../../../../secrets/gotosocial.yaml;
      };
    };
  };
  services = {
    caddy = lib.mkIf config.services.gotosocial.enable {
      # Reverse proxy to the GoToSocial instance
      virtualHosts."${config.services.gotosocial.settings.host}" = {
        extraConfig = ''
          encode zstd gzip
          reverse_proxy ${config.services.gotosocial.settings.bind-address}:${toString config.services.gotosocial.settings.port}
          {
            # Flush immediately, to prevent buffered response to the client
            flush_interval -1
          }
        '';
      };
      # Strip the www. and redirect to the apex domain
      virtualHosts."www.${config.services.gotosocial.settings.host}" = {
        extraConfig = ''
          redir https://${config.services.gotosocial.settings.host}{uri} permanent
        '';
      };
    };
    gotosocial = {
      enable = true;
      environmentFile = config.sops.secrets.gotosocial-env.path;
      settings = {
        bind-address = "127.0.0.1";
        db-type = "sqlite";
        host = "wimpysworld.social";
        instance-expose-public-timeline = true;
        instance-inject-mastodon-version = true;
        instance-languages = [ "en" ];
        landing-page-user = "${username}";
        letsencrypt-enabled = false;
        media-ffmpeg-pool-size = 4;
        port = 8282;
        statuses-max-chars = 1000;
        statuses-media-max-files = 5;
        statuses-poll-max-options = 5;
        storage-local-base-path = "/mnt/data/gotosocial/storage";
      };
    };
  };
  systemd.tmpfiles.rules = [
    "d /mnt/data/gotosocial           0755 gotosocial gotosocial"
    "d /mnt/data/gotosocial/storage   0755 gotosocial gotosocial"
  ];
}
