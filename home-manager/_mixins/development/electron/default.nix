{
  config,
  lib,
  pkgs,
  ...
}:
let
  castlabsSopsFile = ../../../../secrets/castlabs.yaml;
in
{
  home = {
    packages = with pkgs; [
      electron
      (writeShellApplication {
        name = "evs-account";
        text = ''uvx --from castlabs-evs evs-account "$@"'';
      })
      (writeShellApplication {
        name = "evs-vmp";
        text = ''uvx --from castlabs-evs evs-vmp "$@"'';
      })
    ];
  };

  programs = {
    fish = {
      shellInitLast = ''
        # Export Castlabs EVS credentials from sops
        set -gx EVS_ACCOUNT (cat ${config.sops.secrets.EVS_ACCOUNT.path} 2>/dev/null; or echo "")
        set -gx EVS_PASSWD (cat ${config.sops.secrets.EVS_PASSWD.path} 2>/dev/null; or echo "")
      '';
    };
    bash = {
      initExtra = ''
        # Export Castlabs EVS credentials from sops
        export EVS_ACCOUNT=$(cat ${config.sops.secrets.EVS_ACCOUNT.path} 2>/dev/null || echo "")
        export EVS_PASSWD=$(cat ${config.sops.secrets.EVS_PASSWD.path} 2>/dev/null || echo "")
      '';
    };
    zsh = {
      initContent = lib.mkOrder 1000 ''
        # Export Castlabs EVS credentials from sops
        export EVS_ACCOUNT=$(cat ${config.sops.secrets.EVS_ACCOUNT.path} 2>/dev/null || echo "")
        export EVS_PASSWD=$(cat ${config.sops.secrets.EVS_PASSWD.path} 2>/dev/null || echo "")
      '';
    };
  };

  sops = {
    secrets = {
      EVS_ACCOUNT = {
        sopsFile = castlabsSopsFile;
        key = "account_name";
      };
      EVS_PASSWD = {
        sopsFile = castlabsSopsFile;
        key = "password";
      };
    };
  };
}
