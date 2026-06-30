{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
  inherit (config.noughty) host;
  syncDefs = import ../../filesync/syncthing-devices.nix;
  hostHasSyncthingFolder = folderName: lib.elem host.name syncDefs.folders.${folderName}.devices;
  hostHasCryptFolder = hostHasSyncthingFolder "crypt";
  hostHasDevelopmentFolder = hostHasSyncthingFolder "development";
  hostHasGamesFolder = hostHasSyncthingFolder "games";
  isLinuxHostWithCryptFolder = host.is.linux && hostHasCryptFolder;
in
{
  imports = [
    ./atuin.nix
    ./ssh.nix
    ./u2f.nix
    ./gpg.nix
    ./git.nix
  ];

  config = lib.mkIf (noughtyLib.isUser [ "martin" ]) {
    # User-specific sops secrets
    sops.secrets = {
      asciinema.path = "${config.xdg.configHome}/asciinema/config";
      hueadm.path = "${config.home.homeDirectory}/.hueadm.json";
      transifex.path = "${config.home.homeDirectory}/.transifexrc";
    };

    home = {
      file = {
        ".face".source = ./face.png;
        "Development/.keep" = lib.mkIf hostHasDevelopmentFolder { text = ""; };
        "Development/salsa/.envrc" = lib.mkIf hostHasDevelopmentFolder {
          text = "export DEB_VENDOR=Debian";
        };
        "Development/launchpad/.envrc" = lib.mkIf hostHasDevelopmentFolder {
          text = "export DEB_VENDOR=Ubuntu";
        };
        "Development/ubuntu/.envrc" = lib.mkIf hostHasDevelopmentFolder {
          text = "export DEB_VENDOR=Ubuntu";
        };
        "Development/ubuntu-mate/.envrc" = lib.mkIf hostHasDevelopmentFolder {
          text = "export DEB_VENDOR=Ubuntu";
        };
        "Games/.keep" = lib.mkIf hostHasGamesFolder { text = ""; };
        "Zero/.keep".text = "";
      };
      packages = lib.optionals hostHasCryptFolder [
        pkgs.gocryptfs # Terminal encrypted filesystem
      ];
      sessionVariables = {
        DEBFULLNAME = "Martin Wimpress";
        DEBEMAIL = "code@wimpress.io";
        DEBSIGN_KEYID = "8F04688C17006782143279DA61DF940515E06DA3";
      };
    };
    programs = {
      bash.shellAliases = lib.mkIf isLinuxHostWithCryptFolder {
        lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
        unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
        lock-secrets = "fusermount -u ~/Vaults/Secrets";
        unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
      };
      fish.loginShellInit = ''
        # Only show the banner interactively. A non-interactive `fish -lc`
        # (e.g. Codex command hooks) must not print to stdout, or it
        # corrupts the hook's JSON output.
        if status is-interactive
            ${pkgs.figurine}/bin/figurine -f "DOS Rebel.flf" $hostname
        end
      '';
      fish.shellAliases = lib.mkIf isLinuxHostWithCryptFolder {
        lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
        unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
        lock-secrets = "fusermount -u ~/Vaults/Secrets";
        unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
      };
      zsh.shellAliases = lib.mkIf isLinuxHostWithCryptFolder {
        lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
        unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
        lock-secrets = "fusermount -u ~/Vaults/Secrets";
        unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
      };
    };
    systemd.user.tmpfiles = lib.mkIf isLinuxHostWithCryptFolder {
      rules = [
        "d ${config.home.homeDirectory}/Crypt 0755 ${username} users - -"
        "d ${config.home.homeDirectory}/Vaults/Armstrong 0755 ${username} users - -"
        "d ${config.home.homeDirectory}/Vaults/Secrets 0755 ${username} users - -"
      ];
    };
  };
}
