{ hostname, pkgs, username, ... }: {
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=/home/${username}/Syncthing/Devices/${hostname}"
      "--data=/home/${username}/Syncthing/DB/${hostname}"
      "--gui-address=0.0.0.0:8384"
      "--no-default-folder"
      "--no-browser"
    ];
    tray = {
      enable = true;
      package = pkgs.unstable.syncthingtray;
    };
  };
}
