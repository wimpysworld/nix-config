{ config, desktop, hostname, lib, pkgs, username, ... }: {
  home.packages = with pkgs; [
    stc-cli
  ];
  imports = [ ] ++ lib.optionals (desktop != null) [
    ./syncthing-tray.nix
  ];
  programs.fish.shellAliases = {
    stc = "${pkgs.stc-cli}/bin/stc -homedir \"${config.home.homeDirectory}/Syncthing/Devices/${hostname}\"";
  };
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=${config.home.homeDirectory}/Syncthing/Devices/${hostname}"
      "--data=${config.home.homeDirectory}/Syncthing/DB/${hostname}"
      "--gui-address=0.0.0.0:8384"
      "--no-default-folder"
      "--no-browser"
    ];
  };
}
