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
  keybasePackages =
    if isWorkstation then
      [
        pkgs.keybase
        pkgs.keybase-gui
      ]
    else
      [ pkgs.keybase ];
in
lib.mkIf (lib.elem username installFor && !isLima && isLinux) {
  home = {
    file."/Syncthing/.keep".text = "";
    file."${config.xdg.configHome}/keybase/autostart_created".text = ''
      This file is created the first time Keybase starts, along with
      ~/.config/autostart/keybase_autostart.desktop. As long as this
      file exists, the autostart file won't be automatically recreated.
    '';
    packages = with pkgs; [ stc-cli ] ++ lib.optionals (hostname != "bane") keybasePackages;
  };
  programs.fish.shellAliases = {
    stc = "${pkgs.stc-cli}/bin/stc -homedir \"${config.home.homeDirectory}/Syncthing/Devices/${hostname}\"";
  };

  services = {
    kbfs = lib.mkIf (hostname != "bane") {
      enable = true;
      mountPoint = "Keybase";
    };
    keybase = lib.mkIf (hostname != "bane") {
      enable = true;
    };
    syncthing = lib.mkIf (isLinux) {
      enable = true;
      extraOptions = [
        "--config=${config.home.homeDirectory}/Syncthing/Devices/${hostname}"
        "--data=${config.home.homeDirectory}/Syncthing/DB/${hostname}"
        "--no-browser"
      ];
      tray = lib.mkIf isWorkstation {
        enable = isLinux;
        package = pkgs.syncthingtray;
      };
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
  systemd = lib.mkIf isLinux {
    user.targets.tray = lib.mkIf isWorkstation {
      Unit = {
        Description = "Home Manager System Tray";
        Wants = [ "graphical-session-pre.target" ];
      };
    };
    user.services.syncthingtray = lib.mkIf isWorkstation {
      Service.ExecStart = lib.mkForce "${pkgs.syncthingtray}/bin/syncthingtray --wait";
    };
  };
}
