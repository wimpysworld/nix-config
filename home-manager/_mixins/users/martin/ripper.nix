{ hostname, username, ... }: {
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=/home/${username}/Syncthing/Config/${hostname}";
      "--data=/home/${username}/Syncthing/Data/${hostname}";
      "--home=/home/${username}/Syncthing"
      "--gui-address=0.0.0.0:8384"
    ];
    tray.enable = true;
  };
}
