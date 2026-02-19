{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
  host = config.noughty.host;

  # Import Syncthing device and folder definitions
  syncDefs = import ./syncthing-devices.nix;

  # Determine whether this host is a Syncthing cohort member
  isSyncthingHost = builtins.hasAttr host.name syncDefs.devices;

  # Exclude the current host from the devices list
  otherDevices = lib.filterAttrs (name: _: name != host.name) syncDefs.devices;

  # Transform folders: enable only where this host is listed, remove self from devices
  hostFolders = lib.mapAttrs (
    name: folder:
    folder
    // {
      enable = lib.elem host.name folder.devices;
      devices = lib.filter (d: d != host.name) folder.devices;
    }
  ) syncDefs.folders;

  keybasePackages =
    if host.is.workstation then
      [
        pkgs.keybase
        pkgs.keybase-gui
      ]
    else
      [ pkgs.keybase ];
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && !(noughtyLib.hostHasTag "lima")) {
  home = lib.mkIf host.is.linux {
    file."${config.xdg.configHome}/keybase/autostart_created".text = ''
      This file is created the first time Keybase starts, along with
      ~/.config/autostart/keybase_autostart.desktop. As long as this
      file exists, the autostart file won't be automatically recreated.
    '';
    packages =
      with pkgs;
      [ stc-cli ] ++ lib.optionals (!(noughtyLib.hostHasTag "policy")) keybasePackages;
  };

  programs.fish.shellAliases = lib.mkIf host.is.linux {
    stc = "${pkgs.stc-cli}/bin/stc";
  };

  sops.secrets = lib.mkIf isSyncthingHost {
    syncthing_key.sopsFile = ../../../secrets/host-${host.name}.yaml;
    syncthing_cert.sopsFile = ../../../secrets/host-${host.name}.yaml;
    pass.sopsFile = ../../../secrets/syncthing.yaml;
    syncthing_apikey = {
      sopsFile = ../../../secrets/syncthing.yaml;
      key = "apikey";
    };
  };

  services = {
    # Keybase is Linux-only (macOS uses Homebrew cask)
    kbfs = lib.mkIf (host.is.linux && !(noughtyLib.hostHasTag "policy")) {
      enable = true;
      mountPoint = "Keybase";
    };
    keybase = lib.mkIf (host.is.linux && !(noughtyLib.hostHasTag "policy")) {
      enable = true;
    };
    # Syncthing works on both Linux (systemd) and macOS (launchd)
    syncthing = lib.mkIf isSyncthingHost {
      enable = true;
      cert = config.sops.secrets.syncthing_cert.path;
      key = config.sops.secrets.syncthing_key.path;
      overrideDevices = true;
      overrideFolders = true;
      passwordFile = config.sops.secrets.pass.path;
      settings = {
        devices = otherDevices;
        folders = hostFolders;
        gui = {
          theme = "dark";
          user = username;
        };
        options = {
          localAnnounceEnabled = true;
          relaysEnabled = true;
          startBrowser = false;
          urAccepted = -1;
        };
      };
      # Tray is Linux-only (uses systemd and X11/Wayland tray protocol)
      tray = lib.mkIf (host.is.linux && host.is.workstation) {
        enable = true;
        package = pkgs.syncthingtray;
      };
    };
  };

  # Workaround for Failed to restart syncthingtray.service: Unit tray.target not found.
  # - https://github.com/nix-community/home-manager/issues/2064
  systemd = lib.mkIf (host.is.linux && isSyncthingHost) {
    user.targets.tray = lib.mkIf host.is.workstation {
      Unit = {
        Description = "Home Manager System Tray";
        Wants = [ "graphical-session-pre.target" ];
      };
    };
    user.services.syncthing-init.Service.ExecStartPost =
      let
        setApiKey = pkgs.writeShellScript "syncthing-set-apikey" ''
          APIKEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.syncthing_apikey.path})
          CURRENT_KEY=$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "''${XDG_STATE_HOME:-$HOME/.local/state}/syncthing/config.xml")
          ${pkgs.curl}/bin/curl -sSLk \
            -H "X-API-Key: $CURRENT_KEY" \
            -X PATCH \
            -d "{\"apikey\": \"$APIKEY\"}" \
            --retry 5 --retry-delay 2 --retry-all-errors \
            http://127.0.0.1:8384/rest/config/gui
        '';
      in
      "${setApiKey}";
    user.services.syncthingtray = lib.mkIf host.is.workstation {
      Service.ExecStart = lib.mkForce "${pkgs.syncthingtray}/bin/syncthingtray --wait";
    };
  };
}
