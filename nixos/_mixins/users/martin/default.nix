{ config, desktop, hostname, lib, pkgs, ... }:
let
  ifExists = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports = [ ]
  ++ lib.optional (builtins.pathExists (../.. + "/desktop/${desktop}-apps.nix")) ../../desktop/${desktop}-apps.nix
  ++ lib.optionals (desktop != null) [
    ../../desktop/chromium.nix
    ../../desktop/chromium-extensions.nix
    ../../desktop/obs-studio.nix
    ../../desktop/vscode.nix
  ];

  environment.systemPackages = with pkgs; [
    aria2
    croc
    rclone
    wget2
    wormhole-william
    yadm # Terminal dot file manager
    zsync
  ] ++ lib.optionals (desktop != null) [
    appimage-run
    authy
    chatterino2
    cider
    gimp-with-plugins
    gnome.gnome-clocks
    irccloud
    inkscape
    libreoffice
    motrix
    pick-colour-picker
    wmctrl
    xdotool
    ydotool
    zoom-us

    # Fast moving apps use the unstable branch
    unstable.brave
    unstable.discord
    unstable.fluffychat
    unstable.google-chrome
    unstable.microsoft-edge
    unstable.opera
    unstable.tdesktop
    unstable.vivaldi
    unstable.vivaldi-ffmpeg-codecs
  ];

  services = {
    aria2 = {
      enable = true;
      openPorts = true;
      rpcSecret = "${hostname}";
    };
    croc = {
      enable = true;
      pass = "${hostname}";
      openFirewall = true;
    };
  };

  users.users.martin = {
    description = "Martin Wimpress";
    extraGroups = [
      "audio"
      "input"
      "networkmanager"
      "users"
      "video"
      "wheel"
    ]
    ++ ifExists [
      "docker"
      "podman"
    ];
    # mkpasswd -m sha-512
    hashedPassword = "$6$UXNQ20Feu82wCFK9$dnJTeSqoECw1CGMSUdxKREtraO.Nllv3/fW9N3m7lPHYxFKA/Cf8YqYGDmiWNfaKeyx2DKdURo0rPYBrSZRL./";
    homeMode = "0755";
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAywaYwPN4LVbPqkc+kUc7ZVazPBDy4LCAud5iGJdr7g9CwLYoudNjXt/98Oam5lK7ai6QPItK6ECj5+33x/iFpWb3Urr9SqMc/tH5dU1b9N/9yWRhE2WnfcvuI0ms6AXma8QGp1pj/DoLryPVQgXvQlglHaDIL1qdRWFqXUO2u30X5tWtDdOoR02UyAtYBttou4K0rG7LF9rRaoLYP9iCBLxkMJbCIznPD/pIYa6Fl8V8/OVsxYiFy7l5U0RZ7gkzJv8iNz+GG8vw2NX4oIJfAR4oIk3INUvYrKvI2NSMSw5sry+z818fD1hK+soYLQ4VZ4hHRHcf4WV4EeVa5ARxdw== Martin Wimpress"
    ];
    packages = [ pkgs.home-manager ];
    shell = pkgs.fish;
  };
}
