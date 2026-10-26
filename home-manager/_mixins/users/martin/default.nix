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
  hostHasGamesFolder = hostHasSyncthingFolder "games";
  isLinuxHostWithCryptFolder = host.is.linux && hostHasCryptFolder;
  # Match nixos/_mixins/server/maestral and darwin/_mixins/desktop provisioning.
  hostHasMaestral =
    !(noughtyLib.hostHasTag "cg")
    && (host.is.darwin || (host.is.nixos && noughtyLib.hostHasTag "dropbox"));
  gtkBookmarksEnabled = config.gtk.enable && config.gtk.gtk3.enable;
in
{
  imports = [
    ./atuin.nix
    ./ssh.nix
    ./u2f.nix
    ./gpg.nix
    ./git.nix
    ./tokens
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
        # Only show the banner on interactive SSH logins. Gating on
        # SSH_CONNECTION keeps it off local terminals that start a login
        # shell (e.g. wezterm), while still greeting remote connections on
        # any terminal. A non-interactive `fish -lc` (e.g. Codex command
        # hooks) must not print to stdout, or it corrupts the hook's JSON
        # output.
        if status is-interactive; and set -q SSH_CONNECTION
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
    gtk.gtk3.bookmarks = lib.mkIf gtkBookmarksEnabled (
      lib.optional (noughtyLib.userHasTag "developer") "file://${config.xdg.userDirs.extraConfig.DEVELOPMENT} Development"
      ++ lib.optionals hostHasMaestral [
        "file://${config.home.homeDirectory}/Dropbox/Documents/Martin Dropbox-Martin"
        "file://${config.home.homeDirectory}/Dropbox/Documents/Both Dropbox-Both"
      ]
      ++ [
        "file://${config.xdg.userDirs.extraConfig.LINUX_MATTERS} Linux-Matters"
        "file://${config.xdg.userDirs.extraConfig.NOTES} Notes"
        "file://${config.xdg.userDirs.extraConfig.OVAL_TUTU} Oval-Tutu"
        "file://${config.xdg.userDirs.pictures} Pictures"
        "file://${config.xdg.userDirs.videos} Videos"
        "file://${config.xdg.userDirs.extraConfig.VOLATILE} Volatile"
      ]
    );
    xdg.configFile."gtk-3.0/bookmarks" = lib.mkIf (
      gtkBookmarksEnabled && config.gtk.gtk3.bookmarks != [ ]
    ) { force = true; };
    xdg.userDirs.extraConfig = {
      CRYPT = "${config.home.homeDirectory}/Crypt";
      LINUX_MATTERS = "${config.home.homeDirectory}/Linux-Matters";
      NOTES = "${config.home.homeDirectory}/Notes";
      OVAL_TUTU = "${config.home.homeDirectory}/Oval-Tutu";
      VAULTS = "${config.home.homeDirectory}/Vaults";
      VOLATILE = "${config.home.homeDirectory}/Volatile";
    }
    // lib.optionalAttrs (noughtyLib.hostHasTag "cg") {
      CHAINGUARD = "${config.home.homeDirectory}/Chainguard";
    }
    // lib.optionalAttrs (noughtyLib.userHasTag "developer") {
      DEVELOPMENT = "${config.home.homeDirectory}/Development";
    }
    // lib.optionalAttrs (noughtyLib.hostHasTag "studio") {
      STUDIO = "${config.home.homeDirectory}/Studio";
    }
    //
      lib.optionalAttrs
        (noughtyLib.isHost [
          "skrye"
          "zannah"
        ])
        {
          GAMES = "${config.home.homeDirectory}/Games";
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
