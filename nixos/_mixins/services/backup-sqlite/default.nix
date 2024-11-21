{ config, hostname, lib, pkgs, username, ... }:
let
  installOn = [ "malak" ];
  backup-sqlite = pkgs.writeShellApplication {
    name = "backup-sqlite";
    runtimeInputs = with pkgs; [
      coreutils-full
      curl
      findutils
      gzip
      openssl
      sqlite
    ];
    text = builtins.readFile ./backup-sqlite.sh;
  };
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    systemPackages = with pkgs; [
      backup-sqlite
    ];
  };
  sops = {
    secrets = {
      backup-sqlite-env = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/backup-sqlite.conf";
        sopsFile = ../../../../secrets/backup-sqlite.yaml;
      };
    };
  };
  systemd.services.backup-sqlite = {
    description = "Backup SQLite databases";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${backup-sqlite}/bin/backup-sqlite /var/lib/gatus/gatus.db /var/lib/owncast/data/owncast.db'";
      User = "root";
    };
  };

  systemd.timers.backup-sqlite = {
    description = "Run backup-sqlite every 4 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = 300;
    };
  };
}
