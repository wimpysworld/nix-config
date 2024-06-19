{ config, lib, pkgs, ... }:
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
    file."Quickemu/nixos-gnome.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-gnome/disk.qcow2"
      disk_size="96G"
      iso="nixos-gnome/nixos.iso"
      width="1920"
      height="1080"
    '';
    file."Quickemu/nixos-mate.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-mate/disk.qcow2"
      disk_size="96G"
      iso="nixos-mate/nixos.iso"
      width="1920"
      height="1080"
    '';
    file."Quickemu/nixos-pantheon.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-pantheon/disk.qcow2"
      disk_size="96G"
      iso="nixos-pantheon/nixos.iso"
      width="1920"
      height="1080"
    '';
    file."/Development/.keep".text = "";
    file."/Games/.keep".text = "";
    file."/Quickemu/nixos-console/.keep".text = "";
    file."/Quickemu/nixos-gnome/.keep".text = "";
    file."/Quickemu/nixos-mate/.keep".text = "";
    file."/Quickemu/nixos-pantheon/.keep".text = "";
    file."/Scripts/.keep".text = "";
    file."/Syncthing/.keep".text = "";
    file."/Websites/.keep".text = "";
    file."/Zero/.keep".text = "";
    file.".ssh/allowed_signers".text = ''
      martin@wimpress.org ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAywaYwPN4LVbPqkc+kUc7ZVazPBDy4LCAud5iGJdr7g9CwLYoudNjXt/98Oam5lK7ai6QPItK6ECj5+33x/iFpWb3Urr9SqMc/tH5dU1b9N/9yWRhE2WnfcvuI0ms6AXma8QGp1pj/DoLryPVQgXvQlglHaDIL1qdRWFqXUO2u30X5tWtDdOoR02UyAtYBttou4K0rG7LF9rRaoLYP9iCBLxkMJbCIznPD/pIYa6Fl8V8/OVsxYiFy7l5U0RZ7gkzJv8iNz+GG8vw2NX4oIJfAR4oIk3INUvYrKvI2NSMSw5sry+z818fD1hK+soYLQ4VZ4hHRHcf4WV4EeVa5ARxdw== Martin Wimpress
    '';
    sessionVariables = {
      BZR_EMAIL = "Martin Wimpress <code@wimpress.io>";
      DEBFULLNAME = "Martin Wimpress";
      DEBEMAIL = "code@wimpress.io";
      DEBSIGN_KEYID = "8F04688C17006782143279DA61DF940515E06DA3";
    };
  };
  programs = {
    fish.interactiveShellInit = ''
      set -x GH_TOKEN (cat ${config.sops.secrets.gh_token.path})
      set -x GITHUB_TOKEN (cat ${config.sops.secrets.gh_token.path})
    '';
    fish.loginShellInit = ''
      ${pkgs.figurine}/bin/figurine -f "DOS Rebel.flf" $hostname
    '';
    git = {
      extraConfig = {
        gpg = {
          format = "ssh";
          ssh = {
            allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
          };
        };
      };
      userEmail = "martin@wimpress.org";
      userName = "Martin Wimpress";
      signing = {
        key = "${config.home.homeDirectory}/.ssh/id_rsa";
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
      halloy_config.path = "${config.home.homeDirectory}/.config/halloy/config.toml";
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
}
