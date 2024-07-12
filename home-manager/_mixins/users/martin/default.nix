{
  config,
  hostname,
  isWorkstation,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  isStreamstation = hostname == "phasma" || hostname == "vader";
in
{
  home = {
    file."${config.xdg.configHome}/autostart/deskmaster-xl.desktop" = lib.mkIf isStreamstation {
      text = ''
        [Desktop Entry]
        Name=Deckmaster XL
        Comment=Deckmaster XL
        Type=Application
        Exec=deckmaster -deck ${config.home.homeDirectory}/Studio/StreamDeck/Deckmaster-xl/main.deck
        Categories=
        Terminal=false
        NoDisplay=true
        StartupNotify=false
      '';
    };
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
    #fish.interactiveShellInit = ''
    #  set -x GH_TOKEN (cat ${config.sops.secrets.gh_token.path})
    #  set -x GITHUB_TOKEN (cat ${config.sops.secrets.gh_token.path})
    #'';
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

  xdg = lib.mkIf (isLinux && isWorkstation) {
    desktopEntries = {
      cider = {
        name = "Cider";
        exec = "${pkgs.appimage-run}/bin/appimage-run -- ${config.home.homeDirectory}/Apps/Cider-linux-appimage-x64.AppImage";
        terminal = false;
        icon = "${config.home.homeDirectory}/Apps/Cider/logo.png";
        type = "Application";
        categories = [
          "AudioVideo"
          "Audio"
          "Player"
        ];
      };
      heynote = {
        name = "Heynote";
        exec = "${pkgs.appimage-run}/bin/appimage-run -- ${config.home.homeDirectory}/Apps/Heynote_1.7.0_x86_64.AppImage";
        terminal = false;
        icon = "${config.home.homeDirectory}/Apps/Hey/logo.png";
        type = "Application";
        categories = [ "Office" ];
      };
      # The usbimager icon path is hardcoded, so override the desktop file
      usbimager = {
        name = "USBImager";
        exec = "${pkgs.usbimager}/bin/usbimager";
        terminal = false;
        icon = "usbimager";
        type = "Application";
        categories = [
          "System"
          "Application"
        ];
      };
    };
  };
}
