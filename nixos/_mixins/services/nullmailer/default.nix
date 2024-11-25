{ config, hostname, lib, username, ... }:
let
  domain = "wimpys.world";
in
{
  environment ={
    shellAliases = {
      mail-log = "journalctl _SYSTEMD_UNIT=nullmailer.service";
    };
  };
  services.nullmailer = {
    config = {
      me = "${domain}";
      defaultdomain = "${domain}";
      allmailfrom = "${username}@${domain}";
      adminaddr = "${username}@${domain}";
    };
    enable = true;
    remotesFile = config.sops.secrets.mailjet.path;
  };
  sops = {
    secrets = {
      mailjet = {
        group = config.services.nullmailer.group;
        mode = "0600";
        owner = config.services.nullmailer.user;
        path = "/etc/nullmailer/mailjet";
        sopsFile = ../../../../secrets/mailjet.yaml;
      };
    };
  };
}
