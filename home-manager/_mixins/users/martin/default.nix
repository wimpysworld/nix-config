{ config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  ghTokenScript = if isLinux then ''(cat $XDG_RUNTIME_DIR/secrets/gh_token)'' else ''cat (getconf DARWIN_USER_TEMP_DIR)'' + ''/secrets/gh_token'';
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
    file."Quickemu/nixos-gnome.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-gnome/disk.qcow2"
      disk_size="96G"
      iso="nixos-gnome/nixos.iso"
    '';
    file."Quickemu/nixos-mate.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-mate/disk.qcow2"
      disk_size="96G"
      iso="nixos-mate/nixos.iso"
    '';
    file."Quickemu/nixos-pantheon.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-pantheon/disk.qcow2"
      disk_size="96G"
      iso="nixos-pantheon/nixos.iso"
    '';
    file."/Development/.keep".text = "";
    file."/Games/.keep".text = "";
    file."/Quickemu/nixos-console/.keep".text = "";
    file."/Quickemu/nixos-gnome/.keep".text = "";
    file."/Quickemu/nixos-mate/.keep".text = "";
    file."/Quickemu/nixos-pantheon/.keep".text = "";
    file."/Scripts/.keep".text = "";
    file."/Studio/OBS/config/obs-studio/.keep".text = "";
    file."/Syncthing/.keep".text = "";
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
    fish.interactiveShellInit = ''
      set -x GH_TOKEN ${ghTokenScript}
      set -x GITHUB_TOKEN ${ghTokenScript}
    '';
    git = {
      userEmail = "martin@wimpress.org";
      userName = "Martin Wimpress";
      signing = {
        key = "15E06DA3";
        signByDefault = true;
      };
    };
  };

  sops = {
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../../../../secrets/secrets.yaml;
    # sops-nix options: https://dl.thalheim.io/
    secrets = {
      asciinema.path = "${config.home.homeDirectory}/.config/asciinema/config";
      atuin_key.path = "${config.home.homeDirectory}/.local/share/atuin/key";
      flakehub_netrc.path = "${config.home.homeDirectory}/.local/share/flakehub/netrc";
      flakehub_token.path = "${config.home.homeDirectory}/.config/flakehub/auth";
      gh_token = {};
      gpg_private = {};
      gpg_public = {};
      gpg_ownertrust = {};
      halloy_config.path = "${config.home.homeDirectory}/.config/halloy/config.yaml";
      hueadm.path = "${config.home.homeDirectory}/.hueadm.json";
      obs_secrets = {};
      ssh_config.path = "${config.home.homeDirectory}/.ssh/config";
      ssh_key.path = "${config.home.homeDirectory}/.ssh/id_rsa";
      ssh_pub.path = "${config.home.homeDirectory}/.ssh/id_rsa.pub";
      ssh_semaphore_key.path = "${config.home.homeDirectory}/.ssh/id_rsa_semaphore";
      ssh_semaphore_pub.path = "${config.home.homeDirectory}/.ssh/id_rsa_semaphore.pub";
      transifex.path = "${config.home.homeDirectory}/.transifexrc";
    };
  };

  # Linux specific configuration
  systemd.user.tmpfiles.rules = lib.mkIf isLinux [
    "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
  ];
}
