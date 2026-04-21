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
  backupRuntimeInputs = with pkgs; [
    coreutils
    findutils
    gnugrep
    gnutar
    inetutils
    jq
    python3
    rclone
    rsync
    sqlite
    util-linux
    zstd
  ];
  mkHermesBackupScript =
    name: scriptFile:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = backupRuntimeInputs;
      text = ''
        export HERMES_BACKUP_ENV_FILE="${config.sops.templates.${backupEnvTemplate}.path}"
        ${builtins.readFile ./hermes-backup-common.sh}
        ${builtins.readFile scriptFile}
      '';
    };
  backupScript = mkHermesBackupScript "hermes-backup-r2" ./hermes-backup-r2.sh;
  verifyScript = mkHermesBackupScript "hermes-backup-verify-r2" ./hermes-backup-verify-r2.sh;
  restoreScript = mkHermesBackupScript "hermes-restore-r2" ./hermes-restore-r2.sh;
in
lib.mkIf (noughtyLib.hostHasTag "hermes") {
  environment.systemPackages = [
    backupScript
    verifyScript
    restoreScript
  ];

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
      R2_BUCKET_FILE=${config.sops.secrets.R2_BUCKET.path}
      R2_ENDPOINT_FILE=${config.sops.secrets.R2_ENDPOINT.path}
      R2_ACCESS_KEY_ID_FILE=${config.sops.secrets.R2_ACCESS_KEY_ID.path}
      R2_SECRET_ACCESS_KEY_FILE=${config.sops.secrets.R2_SECRET_ACCESS_KEY.path}
      BACKUP_CRYPT_PASSWORD_FILE=${config.sops.secrets.RCLONE_CRYPT_PASSWORD.path}
      BACKUP_CRYPT_PASSWORD2_FILE=${config.sops.secrets.RCLONE_CRYPT_PASSWORD2.path}
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
