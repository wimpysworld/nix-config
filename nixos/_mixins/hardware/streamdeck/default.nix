{
  config,
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
let
  isStreamstation = hostname == "phasma" || hostname == "vader";
  # Bundle all .deck config files into a single store directory so that
  # relative deck references (deck = "foo.deck") resolve correctly.
  deckmaster-xl-config = pkgs.runCommand "deckmaster-xl-config" { } ''
    mkdir -p $out
    cp ${./xl}/*.deck $out/
  '';
in
lib.mkIf (!config.noughty.host.is.iso) {
  environment.systemPackages = with pkgs; [ deckmaster ];

  services = {
    # Provides users with access to all Elgato StreamDecks.
    # https://github.com/muesli/deckmaster
    # https://gitlab.gnome.org/World/boatswain/-/blob/main/README.md#udev-rules
    udev.extraRules = ''
      # Deckmaster needs write access to uinput to simulate keypresses.
      # Users wanting to use Deckmaster should be added to the input group.
      KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"

      # Elgato Stream Deck Mini
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", TAG+="uaccess", SYMLINK+="streamdeck-mini"

      # Elgato Stream Deck Mini (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0090", TAG+="uaccess", SYMLINK+="streamdeck-mini"

      # Elgato Stream Deck Original
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck Original (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck MK.2
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck XL
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", TAG+="uaccess", SYMLINK+="streamdeck-xl"

      # Elgato Stream Deck XL (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="008f", TAG+="uaccess", SYMLINK+="streamdeck-xl"

      # Elgato Stream Deck Pedal
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0086", TAG+="uaccess", SYMLINK+="streamdeck-pedal"
    '';
  };

  users.users.${username} = {
    extraGroups = [ "input" ];
  };

  # Systemd user service for deckmaster on stream workstations
  systemd.user.services.deckmaster-xl = lib.mkIf isStreamstation {
    description = "Deckmaster XL for Stream Deck";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];

    unitConfig = {
      # Restart up to 5 times within 60 seconds before giving up
      StartLimitBurst = 5;
      StartLimitIntervalSec = 60;
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.deckmaster}/bin/deckmaster -deck ${deckmaster-xl-config}/main.deck";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    # Inherit full system PATH so deckmaster can execute shell scripts and system binaries
    environment = {
      PATH = lib.mkForce "/run/wrappers/bin:/home/${username}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";
    };
  };
}
