{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  prodOn = [ "malak" ];
  testOn = [ "revan" ];
  listen = if noughtyLib.isHost prodOn then "127.0.0.1" else "0.0.0.0";
in
lib.mkIf (noughtyLib.isHost (prodOn ++ testOn)) {
  environment = {
    shellAliases = {
      owncast-log = "journalctl _SYSTEMD_UNIT=owncast.service";
    };
    systemPackages = with pkgs; [
      owncast
    ];
  };
  services = {
    caddy = lib.mkIf (config.services.owncast.enable && noughtyLib.isHost prodOn) {
      # Reverse proxy to the Owncast instance
      virtualHosts."wimpysworld.live" = {
        extraConfig = ''
          encode zstd gzip
          reverse_proxy ${config.services.owncast.listen}:${toString config.services.owncast.port}
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/owncast.log
        '';
        serverAliases = [
          "origin.wimpysworld.live"
        ];
      };
      # Strip the www. and redirect to the apex domain
      virtualHosts."www.wimpysworld.live" = {
        extraConfig = ''
          redir https://{labels.1}.{labels.0}{uri} permanent
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/owncast.log
        '';
      };
    };
    owncast = {
      enable = true;
      inherit listen;
      openFirewall = true;
      port = 8383;
    };
  };

  systemd.tmpfiles.rules = [
    # Create the directory for the shader cache required by VA-API on AMD
    "d /var/empty/.cache 0777 nobody users"
  ]
  ++ lib.optionals config.services.geoipupdate.enable [
    # https://owncast.online/docs/viewers/
    "L+ ${config.services.owncast.dataDir}/data/GeoLite2-City.mmdb - - - - ${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-City.mmdb"
  ];
}
