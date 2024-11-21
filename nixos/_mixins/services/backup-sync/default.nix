{ config, hostname, lib, pkgs, username, ... }:
let
  installOn = [ "malak" ];
  backup-sync = pkgs.writeShellApplication {
    name = "backup-sync";
    runtimeInputs = with pkgs; [
      coreutils-full
      curl
      findutils
      gawk
      gnused
      openssh
      rsync
      util-linux
    ];
    text = builtins.readFile ./backup-sync.sh;
  };
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    systemPackages = with pkgs; [
      backup-sync
    ];
  };
  sops = {
    secrets = {
      backup-sync-env = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/backup-sync.env";
        sopsFile = ../../../../secrets/backup-sync.yaml;
      };
    };
  };

  systemd.services.backup-sync = {
    description = "Sync backups to remote server(s)";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${backup-sync}/bin/backup-sync'";
      User = "root";
    };
  };

  systemd.timers.backup-sync = {
    description = "Run backup-sync every 2 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "2h";
      RandomizedDelaySec = 300;
    };
  };
}
