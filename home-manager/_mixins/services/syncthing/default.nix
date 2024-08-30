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
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor && isLinux && !isLima) {
  home = {
    file."/Syncthing/.keep".text = "";
    packages = with pkgs; [ stc-cli ];
  };
  programs.fish.shellAliases = {
    stc = "${pkgs.stc-cli}/bin/stc -homedir \"${config.home.homeDirectory}/Syncthing/Devices/${hostname}\"";
  };
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=${config.home.homeDirectory}/Syncthing/Devices/${hostname}"
      "--data=${config.home.homeDirectory}/Syncthing/DB/${hostname}"
      "--no-default-folder"
      "--no-browser"
    ];
    tray = lib.mkIf isWorkstation {
      enable = true;
      package = pkgs.syncthingtray;
    };
  };

  sops = {
    # sops-nix options: https://dl.thalheim.io/
    secrets = {
      syncthing_apikey = { };
      syncthing_user = { };
      syncthing_pass = { };
    };
  };

  # Workaround for Failed to restart syncthingtray.service: Unit tray.target not found.
  # - https://github.com/nix-community/home-manager/issues/2064
  systemd.user.targets.tray = lib.mkIf isWorkstation {
    Unit = {
      Description = "Home Manager System Tray";
      Wants = [ "graphical-session-pre.target" ];
    };
  };
  # If waybar is enabled, start syncthingtray after waybar so the tray is ready
  systemd.user.services.syncthingtray = lib.mkIf config.programs.waybar.enable {
    Service.ExecStartPre = "${pkgs.coreutils-full}/bin/sleep 0.25";
    Unit.After = lib.mkDefault [ "waybar.service" ];
  };
}
