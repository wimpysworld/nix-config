{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  hermesSopsFile = ../../../../secrets + "/hermes.yaml";
  backupCacheDir = "/var/cache/hermes-backup";
  backupEnvTemplate = "hermes-backup-env";
  backupScript = pkgs.writeShellApplication {
    name = "hermes-backup-r2";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnutar
      inetutils
      jq
      rclone
      rsync
      sqlite
      util-linux
      zstd
    ];
    text = builtins.readFile ./hermes-backup-r2.sh;
  };
in
lib.mkIf (noughtyLib.hostHasTag "hermes") {
  environment.systemPackages = [ backupScript ];

  sops.secrets = {
    R2_BUCKET = {
      sopsFile = hermesSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    R2_ENDPOINT = {
      sopsFile = hermesSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    R2_ACCESS_KEY_ID = {
      sopsFile = hermesSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    R2_SECRET_ACCESS_KEY = {
      sopsFile = hermesSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    RCLONE_CRYPT_PASSWORD = {
      sopsFile = hermesSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    RCLONE_CRYPT_PASSWORD2 = {
      sopsFile = hermesSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  sops.templates.${backupEnvTemplate} = {
    content = ''
      R2_BUCKET=${config.sops.placeholder.R2_BUCKET}
      R2_ENDPOINT=${config.sops.placeholder.R2_ENDPOINT}
      R2_ACCESS_KEY_ID=${config.sops.placeholder.R2_ACCESS_KEY_ID}
      R2_SECRET_ACCESS_KEY=${config.sops.placeholder.R2_SECRET_ACCESS_KEY}
      RCLONE_CRYPT_PASSWORD=${config.sops.placeholder.RCLONE_CRYPT_PASSWORD}
      RCLONE_CRYPT_PASSWORD2=${config.sops.placeholder.RCLONE_CRYPT_PASSWORD2}
    '';
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.services.hermes-backup = {
    description = "Backup Hermes state to Cloudflare R2";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      EnvironmentFile = config.sops.templates.${backupEnvTemplate}.path;
      ExecStart = "${backupScript}/bin/hermes-backup-r2";
      CacheDirectory = "hermes-backup";
      WorkingDirectory = backupCacheDir;
    };
  };

  systemd.timers.hermes-backup = {
    description = "Run Hermes R2 backup every 6 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00,06,12,18:00:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };
}
