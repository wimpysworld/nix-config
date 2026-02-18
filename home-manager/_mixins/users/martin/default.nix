{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
in
{
  imports = [
    ./atuin.nix
    ./ssh.nix
    ./u2f.nix
    ./gpg.nix
    ./git.nix
  ];

  # User-specific sops secrets
  sops.secrets = {
    asciinema.path = "${config.home.homeDirectory}/.config/asciinema/config";
    hueadm.path = "${config.home.homeDirectory}/.hueadm.json";
    transifex.path = "${config.home.homeDirectory}/.transifexrc";
  };

  home = {
    file.".face".source = ./face.png;
    file."Development/.keep" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) { text = ""; };
    file."Development/salsa/.envrc" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
      text = "export DEB_VENDOR=Debian";
    };
    file."Development/launchpad/.envrc" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Development/ubuntu/.envrc" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Development/ubuntu-mate/.envrc" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Games/.keep" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) { text = ""; };
    file."Websites/.keep" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) { text = ""; };
    file."Zero/.keep".text = "";
    packages = lib.optionals (!(noughtyLib.hostHasTag "lima")) [
      pkgs.gocryptfs # Terminal encrypted filesystem
    ];
    sessionVariables = {
      DEBFULLNAME = "Martin Wimpress";
      DEBEMAIL = "code@wimpress.io";
      DEBSIGN_KEYID = "8F04688C17006782143279DA61DF940515E06DA3";
    };
  };
  programs = {
    bash.shellAliases = lib.mkIf (pkgs.stdenv.isLinux && !(noughtyLib.hostHasTag "lima")) {
      lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
      unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
      lock-secrets = "fusermount -u ~/Vaults/Secrets";
      unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
    };
    fish.loginShellInit = ''
      ${pkgs.figurine}/bin/figurine -f "DOS Rebel.flf" $hostname
    '';
    fish.shellAliases = lib.mkIf (pkgs.stdenv.isLinux && !(noughtyLib.hostHasTag "lima")) {
      lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
      unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
      lock-secrets = "fusermount -u ~/Vaults/Secrets";
      unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
    };
    zsh.shellAliases = lib.mkIf (pkgs.stdenv.isLinux && !(noughtyLib.hostHasTag "lima")) {
      lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
      unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
      lock-secrets = "fusermount -u ~/Vaults/Secrets";
      unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
    };
  };
  systemd.user.tmpfiles = lib.mkIf (pkgs.stdenv.isLinux && !(noughtyLib.hostHasTag "lima")) {
    rules = [
      "d ${config.home.homeDirectory}/Crypt 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Armstrong 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Secrets 0755 ${username} users - -"
    ];
  };
}
