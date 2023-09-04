{ config, desktop, hostname, lib, pkgs, username, ... }: {
  imports = [ ] ++ lib.optionals (desktop != null) [
    ./syncthing-tray.nix
  ];

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
