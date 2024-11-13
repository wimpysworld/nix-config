{ config, hostname, lib, pkgs, username, ... }:
let
  installOn = [ "malak" ];
  replicateGotosocial = config.services.litestream.enable && config.services.gotosocial.enable && config.services.gotosocial.settings.db-type == "sqlite";
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      litestream-log = "journalctl _SYSTEMD_UNIT=litestream.service";
    };
    systemPackages = with pkgs; [
      sqlite
    ];
  };
  # TODO: Add a local package that includes the patches
  # - I'm not using SSH so not affected by the CVE
  nixpkgs.config.permittedInsecurePackages = [
    "litestream-0.3.13"
  ];
  services = {
    litestream = {
      enable = true;
      settings = {
        dbs = lib.optionals replicateGotosocial [{
          path = "${config.services.gotosocial.settings.db-address}";
          replicas = [{
            path = "/mnt/data/litestream/gotosocial/database.sqlite";
          }];
        }];
      };
    };
  };

  # Wait for the SQLite WAL to be created before granting permissions so that
  # Litestream has read/write access to the database
  # https://nixos.org/manual/nixos/stable/#module-services-litestream
  systemd.services.gotosocial = lib.mkIf replicateGotosocial {
    serviceConfig.ExecStartPost = "+" + pkgs.writeShellScript "grant-gotosocial-permissions" ''
      for ((i=10; i>0; i--)); do
        [[ -f ${config.services.gotosocial.settings.db-address}-wal ]] && break
        sleep 1
      done
      [[ $i == 0 ]] && { echo "ERROR: Timeout while waiting for ${config.services.gotosocial.settings.db-address}" >&2; exit 1; }
      ${pkgs.findutils}/bin/find $(dirname "${config.services.gotosocial.settings.db-address}") -type d -exec chmod -v 775 {} + -o -type f -exec chmod -v 664 {} +
    '';
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data/litestream 0755 litestream litestream"
  ];

  # Add litestream user to the gotosocial group
  users.users = lib.mkIf config.services.litestream.enable {
    litestream.extraGroups = lib.optionals replicateGotosocial [
      "gotosocial"
    ];
  };
}
