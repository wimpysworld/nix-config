{
  config,
  hostname,
  isLima,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./ssh.nix
    ./u2f.nix
    ./gpg.nix
  ];

  # User-specific sops secrets
  sops.secrets = {
    asciinema.path = "${config.home.homeDirectory}/.config/asciinema/config";
    hueadm.path = "${config.home.homeDirectory}/.hueadm.json";
    transifex.path = "${config.home.homeDirectory}/.transifexrc";
  };

  home = {
    file.".face".source = ./face.png;
    file."Development/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Development/salsa/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Debian";
    };
    file."Development/launchpad/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Development/ubuntu/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Development/ubuntu-mate/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Games/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Websites/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Zero/.keep".text = "";
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
    lazygit.settings.git.commit = {
      # Add Signed-off-by trailer to commits (DCO compliance)
      signOff = true;
    };
  };
  systemd.user.tmpfiles = lib.mkIf (pkgs.stdenv.isLinux && !isLima) {
    rules = [
      "d ${config.home.homeDirectory}/Crypt 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Armstrong 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Secrets 0755 ${username} users - -"
    ];
  };
}
