{ config, lib, hostname, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  imports = [
    ../../services/keybase.nix
    ../../services/syncthing.nix
  ];
  home = {
    file.".bazaar/authentication.conf".text = "
      [Launchpad]
      host = .launchpad.net
      scheme = ssh
      user = flexiondotorg
    ";
    file.".bazaar/bazaar.conf".text = "
      [DEFAULT]
      email = Martin Wimpress <code@wimpress.io>
      launchpad_username = flexiondotorg
      mail_client = default
      tab_width = 4
      [ALIASES]
    ";
    file.".face".source = ./face.png;
    file."Development/salsa.debian.org/.envrc".text = "export DEB_VENDOR=Debian";
    file."Development/git.launchpad.net/.envrc".text = "export DEB_VENDOR=Ubuntu";
    file."Development/github.com/ubuntu/.envrc".text = "export DEB_VENDOR=Ubuntu";
    file."Development/github.com/ubuntu-mate/.envrc".text = "export DEB_VENDOR=Ubuntu";
    file."Quickemu/nixos-console.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-console/disk.qcow2"
      disk_size="96G"
      iso="nixos-console/nixos.iso"
    '';
    file."Quickemu/nixos-desktop.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-desktop/disk.qcow2"
      disk_size="96G"
      iso="nixos-desktop/nixos.iso"
    '';
    file."/Development/.keep".text = "";
    file."/Games/.keep".text = "";
    file."/Quickemu/nixos-console/.keep".text = "";
    file."/Quickemu/nixos-desktop/.keep".text = "";
    file."/Scripts/.keep".text = "";
    file."/Studio/OBS/config/obs-studio/.keep".text = "";
    file."/Syncthing/.keep".text = "";
    file."/Volatile/Vorta/.keep".text = "";
    file."/Websites/.keep".text = "";
    file."/Zero/.keep".text = "";

    sessionVariables = {
      BZR_EMAIL = "Martin Wimpress <code@wimpress.io>";
      DEBFULLNAME = "Martin Wimpress";
      DEBEMAIL = "code@wimpress.io";
      DEBSIGN_KEYID = "8F04688C17006782143279DA61DF940515E06DA3";
    };
  };
  programs = {
    git = {
      userEmail = "martin@wimpress.org";
      userName = "Martin Wimpress";
      signing = {
        key = "15E06DA3";
        signByDefault = true;
      };
    };
  };

  # Linux specific configuration
  systemd.user.tmpfiles.rules = lib.mkIf isLinux [
    "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
  ];
}
