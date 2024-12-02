{
  config,
  hostname,
  isLima,
  isWorkstation,
  lib,
  pkgs,
  username,
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
    file."Development/salsa.debian.org/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Debian'';
    };
    file."Development/git.launchpad.net/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Ubuntu'';
    };
    file."Development/github.com/ubuntu/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Ubuntu'';
    };
    file."Development/github.com/ubuntu-mate/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Ubuntu'';
    };
    file."Quickemu/nixos-console.conf" = lib.mkIf (!isLima) {
      text = ''
        #!/run/current-system/sw/bin/quickemu --vm
        guest_os="linux"
        disk_img="nixos-console/disk.qcow2"
        disk_size="96G"
        iso="nixos-console/nixos.iso"
      '';
    };
    file."Quickemu/nixos-gnome.conf" = lib.mkIf (!isLima) {
      text = ''
        #!/run/current-system/sw/bin/quickemu --vm
        guest_os="linux"
        disk_img="nixos-gnome/disk.qcow2"
        disk_size="96G"
        iso="nixos-gnome/nixos.iso"
        width="1920"
        height="1080"
      '';
    };
    file."Quickemu/nixos-mate.conf" = lib.mkIf (!isLima) {
      text = ''
        #!/run/current-system/sw/bin/quickemu --vm
        guest_os="linux"
        disk_img="nixos-mate/disk.qcow2"
        disk_size="96G"
        iso="nixos-mate/nixos.iso"
        width="1920"
        height="1080"
      '';
    };
    file."Quickemu/nixos-pantheon.conf" = lib.mkIf (!isLima) {
      text = ''
        #!/run/current-system/sw/bin/quickemu --vm
        guest_os="linux"
        disk_img="nixos-pantheon/disk.qcow2"
        disk_size="96G"
        iso="nixos-pantheon/nixos.iso"
        width="1920"
        height="1080"
      '';
    };
    file."/Development/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."/Games/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."/Quickemu/nixos-console/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."/Quickemu/nixos-gnome/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."/Quickemu/nixos-mate/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."/Quickemu/nixos-pantheon/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."/Scripts/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."/Websites/.keep" = lib.mkIf (!isLima) { text = ""; };
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
      set -x GH_TOKEN (${pkgs.coreutils}/bin/cat ${config.sops.secrets.gh_token.path} 2>/dev/null)
      set -x GITHUB_TOKEN (${pkgs.coreutils}/bin/cat ${config.sops.secrets.gh_token.path} 2>/dev/null)
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
  systemd.user.tmpfiles = lib.mkIf (isLinux && !isLima) {
    rules = [
      "d ${config.home.homeDirectory}/Crypt 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Armstrong 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Secrets 0755 ${username} users - -"
    ];
  };
}
