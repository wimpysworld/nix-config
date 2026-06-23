{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
{
  config =
    lib.mkIf
      (
        noughtyLib.isUser [ "martin" ] && config.noughty.host.is.linux && config.noughty.host.is.workstation
      )
      {
        sops.secrets.SOJU_PASSWORD.sopsFile = ../../../secrets/halloy.yaml;

        programs.senpai = {
          enable = true;
          config = {
            address = "irc+insecure://revan.${config.noughty.network.tailNet}:6667";
            nickname = "Wimpy";
            username = config.noughty.user.name;
            password-cmd = [
              "${pkgs.coreutils}/bin/cat"
              config.sops.secrets.SOJU_PASSWORD.path
            ];
          };
        };
      };
}
