{
  config,
  hostname,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
in
lib.mkIf (noughtyLib.isHost [ "vader" ]) {
  environment.systemPackages = with pkgs; [ transmission_4 ];

  services.transmission = {
    credentialsFile = config.sops.secrets.transmission.path;
    downloadDirPermissions = "755";
    enable = true;
    home = "/srv/transmission";
    openFirewall = false;
    openRPCPort = true;
    openPeerPorts = false;
    package = pkgs.transmission_4;
    performanceNetParameters = true;
    user = "${username}";
    group = "users";
    webHome = pkgs.flood-for-transmission;
    settings = {
      alt-speed-enabled = false;
      announce-ip = "";
      announce-ip-enabled = false;
      blocklist-enabled = true;
      blocklist-url = "https://raw.githubusercontent.com/Naunter/BT_BlockLists/master/bt_blocklists.gz";
      download-dir = "${config.services.transmission.home}/Downloads";
      encryption = 2;
      idle-seeding-limit = 60;
      idle-seeding-limit-enabled = false;
      incomplete-dir = "${config.services.transmission.home}/Incomplete";
      incomplete-dir-enabled = true;
      peer-limit-global = 512;
      peer-limit-per-torrent = 128;
      peer-port-random-on-start = true;
      peer-port-random-low = 49152;
      peer-port-random-high = 65535;
      ratio-limit = 2.0000;
      ratio-limit-enabled = true;
      rpc-authentication-required = false;
      rpc-enabled = true;
      rpc-host-whitelist = "localhost,${hostname},*.${config.noughty.network.tailNet}";
      rpc-host-whitelist-enabled = true;
      rpc-bind-address = "0.0.0.0";
      rpc-port = 9091;
      rpc-whitelist = "127.0.0.*,10.10.10.*,100.*.*.*";
      rpc-whitelist-enabled = true;
      speed-limit-down = 100;
      speed-limit-down-enabled = false;
      speed-limit-up = 100;
      speed-limit-up-enabled = false;
      start-added-torrents = true;
      start_paused = true;
      trash-can-enabled = false;
      trash-original-torrent-files = true;
      watch-dir = "${config.services.transmission.home}/Watch";
      watch-dir-enabled = true;
    };
  };

  sops = {
    secrets = {
      transmission = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/transmission/credentials.json";
        sopsFile = ../../../../secrets/transmission.yaml;
      };
    };
  };

  systemd.services.transmission-blocklist-update = {
    description = "Update Transmission blocklist";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.transmission_4}/bin/transmission-remote --blocklist-update'";
      User = "${username}";
      Group = "users";
    };
  };

  systemd.timers.transmission-blocklist-update = {
    description = "Run Transmission blocklist update every day";
    after = [ "transmission.service" ];
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "24h";
      RandomizedDelaySec = 300;
    };
  };

}
