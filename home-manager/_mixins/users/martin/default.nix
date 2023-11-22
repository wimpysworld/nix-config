{ config, lib, hostname, pkgs, username, ... }: {
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
    file.".ssh/config".text = "
      Host github.com
        HostName github.com
        User git

      Host man
        HostName man.wimpress.io

      Host yor
        HostName yor.wimpress.io

      Host man.ubuntu-mate.net
        HostName man.ubuntu-mate.net
        User matey
        IdentityFile ~/.ssh/id_rsa_semaphore

      Host yor.ubuntu-mate.net
        HostName yor.ubuntu-mate.net
        User matey
        IdentityFile ~/.ssh/id_rsa_semaphore

      Host bazaar.launchpad.net
        User flexiondotorg

      Host git.launchpad.net
        User flexiondotorg

      Host ubuntu.com
        HostName people.ubuntu.com
        User flexiondotorg

      Host people.ubuntu.com
        User flexiondotorg

      Host ubuntupodcast.org
        HostName live.ubuntupodcast.org
    ";
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

  # TODO: Ignore on Darwin
  #systemd.user.tmpfiles.rules = [
  #  "d ${config.home.homeDirectory}/Development 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Dropbox 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Games 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Quickemu/nixos-console 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Quickemu/nixos-desktop 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Scripts 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/ 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Syncthing 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Volatile/Vorta 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Websites 0755 ${username} users - -"
  #  "d ${config.home.homeDirectory}/Zero 0755 ${username} users - -"
  #  "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
  #];
}
