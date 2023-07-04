{ lib, hostname, username, ... }: {
  imports = [ ]
  ++ lib.optional (builtins.pathExists (./. + "/hosts/${hostname}.nix")) ./hosts/${hostname}.nix;

  home.file.".face".source = ./face.png;
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
  systemd.user.tmpfiles.rules = [
    "d /home/${username}/Audio 0755 ${username} users - -"
    "d /home/${username}/Development 0755 ${username} users - -"
    "d /home/${username}/Dropbox 0755 ${username} users - -"
    "d /home/${username}/Games 0755 ${username} users - -"
    "d /home/${username}/Quickemu 0755 ${username} users - -"
    "d /home/${username}/Scripts 0755 ${username} users - -"
    "d /home/${username}/Studio 0755 ${username} users - -"
    "d /home/${username}/Syncthing 0755 ${username} users - -"
    "d /home/${username}/Volatile 0755 ${username} users - -"
    "d /home/${username}/Websites 0755 ${username} users - -"
    "d /home/${username}/Zero 0755 ${username} users - -"
  ];
}
