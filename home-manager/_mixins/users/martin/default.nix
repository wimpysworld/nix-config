{
  config,
  hostname,
  isLima,
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
    file.".face".source = ./face.png;
    file."Development/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Development/salsa/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Debian'';
    };
    file."Development/launchpad/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Ubuntu'';
    };
    file."Development/ubuntu/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Ubuntu'';
    };
    file."Development/ubuntu-mate/.envrc" = lib.mkIf (!isLima) {
      text = ''export DEB_VENDOR=Ubuntu'';
    };
    file."Games/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Quickemu/nixos-console/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Quickemu/nixos-console.conf" = lib.mkIf (!isLima) {
      text = ''
        #!/run/current-system/sw/bin/quickemu --vm
        guest_os="linux"
        disk_img="nixos-console/disk.qcow2"
        disk_size="96G"
        iso="nixos-console/nixos.iso"
      '';
    };
    file."Websites/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Zero/.keep".text = "";
    file.".ssh/allowed_signers".text = ''
      martin@wimpress.org ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAywaYwPN4LVbPqkc+kUc7ZVazPBDy4LCAud5iGJdr7g9CwLYoudNjXt/98Oam5lK7ai6QPItK6ECj5+33x/iFpWb3Urr9SqMc/tH5dU1b9N/9yWRhE2WnfcvuI0ms6AXma8QGp1pj/DoLryPVQgXvQlglHaDIL1qdRWFqXUO2u30X5tWtDdOoR02UyAtYBttou4K0rG7LF9rRaoLYP9iCBLxkMJbCIznPD/pIYa6Fl8V8/OVsxYiFy7l5U0RZ7gkzJv8iNz+GG8vw2NX4oIJfAR4oIk3INUvYrKvI2NSMSw5sry+z818fD1hK+soYLQ4VZ4hHRHcf4WV4EeVa5ARxdw== Martin Wimpress
    '';
    # Configure gpg-agent SSH keys for Git signing
    file.".gnupg/sshcontrol" = {
      text = ''
        # SSH key for Git commit signing (id_rsa)
        # Keygrip for: ${config.home.homeDirectory}/.ssh/id_rsa
        EAC48EAAD36DC5B3460F9FC8FBD68DEED4DECD0F 0
      '';
      force = true;
    };
    sessionVariables = {
      DEBFULLNAME = "Martin Wimpress";
      DEBEMAIL = "code@wimpress.io";
      DEBSIGN_KEYID = "8F04688C17006782143279DA61DF940515E06DA3";
    };
  };
  programs = {
    fish.loginShellInit = ''
      ${pkgs.figurine}/bin/figurine -f "DOS Rebel.flf" $hostname
    '';
    git = {
      settings = {
        gpg = {
          ssh = {
            allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
          };
        };
        user = {
          email = "martin@wimpress.org";
          name = "Martin Wimpress";
        };
      };
      signing = {
        format = "ssh";
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
