{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  hasRazerPeripherals = if (hostname == "phasma" || hostname == "vader") then true else false;
in
{
  imports = [
    ./features/flatpak
    ./features/pipewire
    ./apps/chromium
    ./apps/firefox
    ./apps/obs-studio
    ./apps/steam
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
    appimage-run
    wmctrl
    xdotool
    ydotool
  ] ++ lib.optionals (isInstall && hasRazerPeripherals) [
    polychromatic
  ];

  fonts = {
    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultPackages = false;
    fontDir.enable = true;
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })
      fira
      liberation_ttf
      noto-fonts-emoji
      source-serif
      twitter-color-emoji
      work-sans
    ] ++ lib.optionals (isInstall) [
      ubuntu_font_family
    ];

    fontconfig = {
      antialias = true;
      # Enable 32-bit support for Steam
      cache32Bit = config.programs.steam.enable;
      defaultFonts = {
        serif = [ "Source Serif" ];
        sansSerif = [ "Work Sans" "Fira Sans" ];
        monospace = [ "FiraCode Nerd Font Mono" "Symbols Nerd Font Mono" ];
        emoji = [ "Noto Color Emoji" "Twitter Color Emoji" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  hardware = {
    openrazer = lib.mkIf (hasRazerPeripherals) {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      mouseBatteryNotifier = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
    sane = lib.mkIf (isInstall) {
      enable = true;
      #extraBackends = with pkgs; [ hplipWithPlugin sane-airscan ];
      extraBackends = with pkgs; [ sane-airscan ];
    };
  };

  programs = {
    appimage.binfmt = true;
    system-config-printer = lib.mkIf (isInstall) {
      enable = if (desktop == "mate") then true else false;
    };
  };

  services = {
    printing = lib.mkIf (isInstall) {
      enable = true;
      drivers = with pkgs; [ gutenprint hplip ];
    };
    system-config-printer.enable = isInstall;

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

      # Expose important timers the members of the audio group
      # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L94
      KERNEL=="rtc0", GROUP="audio"
      KERNEL=="hpet", GROUP="audio"
      # Allow users in the audio group to change cpu dma latency
      DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
    '';

    # Disable xterm
    xserver = {
      desktopManager.xterm.enable = false;
      # Disable autoSuspend; my Pantheon session kept auto-suspending
      # - https://discourse.nixos.org/t/why-is-my-new-nixos-install-suspending/19500
      displayManager.gdm.autoSuspend = if (desktop == "pantheon") then true else false;
      excludePackages = [ pkgs.xterm ];
    };
  };

  xdg.portal = {
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };
    enable = true;
    xdgOpenUsePortal = true;
  };
}
