{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
{
  imports = [
    ./features/appimage
    ./features/flatpak
    ./features/fonts
    ./features/pipewire
    ./features/print
    ./features/scan
    ./features/xdg
    ./apps/1password
    ./apps/blender
    ./apps/chromium
    ./apps/firefox
    ./apps/obs-studio
    ./apps/steam
    ./apps/video-production
  ] ++ lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop};

  boot = {
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" ];
    plymouth = {
      catppuccin.enable = if (username == "martin") then true else false;
      enable = true;
    };
  };

  environment.etc = {
    "backgrounds/DeterminateColorway-1920x1080.png".source = ../configs/backgrounds/DeterminateColorway-1920x1080.png;
    "backgrounds/DeterminateColorway-1920x1200.png".source = ../configs/backgrounds/DeterminateColorway-1920x1200.png;
    "backgrounds/DeterminateColorway-2560x1440.png".source = ../configs/backgrounds/DeterminateColorway-2560x1440.png;
    "backgrounds/DeterminateColorway-3440x1440.png".source = ../configs/backgrounds/DeterminateColorway-3440x1440.png;
    "backgrounds/DeterminateColorway-3840x2160.png".source = ../configs/backgrounds/DeterminateColorway-3840x2160.png;
  };

  environment.systemPackages = with pkgs; [
    catppuccin-cursors.mochaBlue
    (catppuccin-gtk.override {
      accents = [ "blue" ];
      size = "standard";
      variant = "mocha";
    })
    (catppuccin-papirus-folders.override {
      flavor = "mocha";
      accent = "blue";
    })
  ] ++ lib.optionals (isInstall) [
    wmctrl
    xdotool
    ydotool
  ];

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

    # Disable xterm
    xserver = {
      desktopManager.xterm.enable = false;
      excludePackages = [ pkgs.xterm ];
    };
  };
}
