{
  config,
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
let
  # Declare which hosts have Transmission enabled.
  installOn = [
    "vader"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  environment.systemPackages = with pkgs; [ transmission_4 ];

  services.transmission = {
    credentialsFile = config.sops.secrets.transmission.path;
    downloadDirPermissions = "755";
    enable = true;
    home = "/srv/transmission";
    package = pkgs.transmission_4;
    user = "${username}";
    group = "users";
    webHome = pkgs.flood-for-transmission;
    settings = {
      blocklist-enabled = true;
      blocklist-updates-enabled = true;
      blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";
      download-dir = "${config.services.transmission.home}/Downloads";
      encryption = 2;
      idle-seeding-limit = 60;
      idle-seeding-limit-enabled = false;
      incomplete-dir = "${config.services.transmission.home}/Incomplete";
      incomplete-dir-enabled = true;
      openFirewall = false;
      openRPCPort = true;
      openPeerPorts = true;
      peer-limit-global = 512;
      peer-limit-per-torrent = 128;
      peer-port-random-on-start = true;
      peer-port-random-low = 49152;
      peer-port-random-high = 65535;
      ratio-limit = 2.0000;
      ratio-limit-enabled = true;
      rpc-authentication-required = true;
      rpc-enabled = true;
      rpc-host-whitelist = "";
      rpc-host-whitelist-enabled = true;
      rpc-whitelist-enabled = false;
      rpc-bind-address = "0.0.0.0";
      rpc-port = 9091;
      speed-limit-down = 100;
      speed-limit-down-enabled = false;
      speed-limit-up = 100;
      speed-limit-up-enabled = false;
      start-added-torrents = true;
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
}
