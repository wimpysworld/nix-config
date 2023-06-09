{ config, desktop, hostname, inputs, lib, modulesPath, outputs, pkgs, stateVersion, username, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    (modulesPath + "/installer/scan/not-detected.nix")
    ./${hostname}
    ./_mixins/services/firewall.nix
    ./_mixins/services/fwupd.nix
    ./_mixins/services/kmscon.nix
    ./_mixins/services/openssh.nix
    ./_mixins/users/root
    ./_mixins/users/${username}
  ] ++ lib.optional (builtins.isString desktop) ./_mixins/desktop;

  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelModules = [ "vhost_vsock" ];
    kernelParams = [
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };

  console = {
    earlySetup = true;
    font = "${pkgs.tamzen}/share/consolefonts/TamzenForPowerline10x20.psf";
    keyMap = "uk";
    packages = with pkgs; [ tamzen ];
  };

  i18n = {
    defaultLocale = "en_GB.utf8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_GB.utf8";
      LC_IDENTIFICATION = "en_GB.utf8";
      LC_MEASUREMENT = "en_GB.utf8";
      LC_MONETARY = "en_GB.utf8";
      LC_NAME = "en_GB.utf8";
      LC_NUMERIC = "en_GB.utf8";
      LC_PAPER = "en_GB.utf8";
      LC_TELEPHONE = "en_GB.utf8";
      LC_TIME = "en_GB.utf8";
    };
  };
  services.xserver.layout = "gb";
  time.timeZone = "Europe/London";

  # Only install the docs I use
  documentation.enable = true;        # documentation of packages
  documentation.nixos.enable = false; # nixos documentation
  documentation.man.enable = true;    # man pages and the man command
  documentation.info.enable = false;  # info pages and the info command
  documentation.doc.enable = false;   # documentation distributed in packages' /share/doc

  environment = {
    # Eject nano and perl from the system
    defaultPackages = with pkgs; lib.mkForce [
      gitMinimal
      home-manager
      micro
      rsync
    ];
    systemPackages = with pkgs; [
      pciutils
      psmisc
      unzip
      usbutils
    ];
    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" "UbuntuMono"]; })
      fira
      fira-go
      joypixels
      liberation_ttf
      noto-fonts-emoji
      source-serif
      ubuntu_font_family
      work-sans
    ];

    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultFonts = false;

    fontconfig = {
      antialias = true;
      defaultFonts = {
        serif = [ "Source Serif" ];
        sansSerif = [ "Work Sans" "Fira Sans" "FiraGO" ];
        monospace = [ "FiraCode Nerd Font Mono" "SauceCodePro Nerd Font Mono" ];
        emoji = [ "Joypixels" "Noto Color Emoji" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "hintslight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  # Use passed hostname to configure basic networking
  networking = {
    extraHosts = ''
    192.168.192.40  skull-zt
    192.168.192.59  trooper-zt
    192.168.192.181 zed-zt
    192.168.192.220 ripper-zt
    192.168.192.162 p1-zt
    192.168.192.249 p2-max-zt
    #192.168.192.0   brix-zt
    #192.168.192.0   nuc-zt
    
    '';
    hostName = hostname;
    useDHCP = lib.mkDefault true;
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Accept the joypixels license
      joypixels.acceptLicense = true;
    };
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    optimise.automatic = true;
    package = pkgs.unstable.nix;
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
  };

  programs = {
    command-not-found.enable = false;
    fish = {
      enable = true;
      interactiveShellInit = ''
      set fish_cursor_default block blink
      set fish_cursor_insert line blink
      set fish_cursor_replace_one underscore blink
      set fish_cursor_visual block
      set -U fish_color_autosuggestion brblack
      set -U fish_color_cancel -r
      set -U fish_color_command green
      set -U fish_color_comment brblack
      set -U fish_color_cwd brgreen
      set -U fish_color_cwd_root brred
      set -U fish_color_end brmagenta
      set -U fish_color_error red
      set -U fish_color_escape brcyan
      set -U fish_color_history_current --bold
      set -U fish_color_host normal
      set -U fish_color_match --background=brblue
      set -U fish_color_normal normal
      set -U fish_color_operator cyan
      set -U fish_color_param blue
      set -U fish_color_quote yellow
      set -U fish_color_redirection magenta
      set -U fish_color_search_match bryellow '--background=brblack'
      set -U fish_color_selection white --bold '--background=brblack'
      set -U fish_color_status red
      set -U fish_color_user brwhite
      set -U fish_color_valid_path --underline
      set -U fish_pager_color_completion normal
      set -U fish_pager_color_description yellow
      set -U fish_pager_color_prefix white --bold --underline
      set -U fish_pager_color_progress brwhite '--background=cyan'
      '';
      shellAbbrs = {
        nix-gc              = "sudo nix-collect-garbage --delete-older-than 14d";
        rebuild-all         = "rebuild-host && rebuild-home";
        rebuild-home        = "home-manager switch -b backup --flake $HOME/Zero/nix-config";
        rebuild-host        = "sudo nixos-rebuild switch --flake $HOME/Zero/nix-config";
        rebuild-lock        = "pushd $HOME/Zero/nix-config && nix flake lock --recreate-lock-file && popd";
        rebuild-iso-console = "pushd $HOME/Zero/nix-config && nix build .#nixosConfigurations.iso-console.config.system.build.isoImage && popd";
        rebuild-iso-desktop = "pushd $HOME/Zero/nix-config && nix build .#nixosConfigurations.iso-desktop.config.system.build.isoImage && popd";
      };
      shellAliases = {
        moon = "curl -s wttr.in/Moon";
        nano = "micro";
        open = "xdg-open";
        pubip = "curl -s ifconfig.me/ip";
        #pubip = "curl -s https://api.ipify.org";
        wttr = "curl -s wttr.in && curl -s v2.wttr.in";
        wttr-bas = "curl -s wttr.in/basingstoke && curl -s v2.wttr.in/basingstoke";
      };
    };
    # nano.syntaxHighlight = true;
    # nano.nanorc = ''
    #   set autoindent   # Auto indent
    #   set constantshow # Show cursor position at the bottom of the screen
    #   set fill 78      # Justify command (Ctrl+j) wraps at 78 columns
    #   set historylog   # Remember command history
    #   set multibuffer  # Allow opening multiple files (Alt+< and Alt+> to switch)
    #   set nohelp       # Remove the help bar from the bottom of the screen
    #   set nowrap       # Do not wrap text
    #   set quickblank   # Clear status messages after a single keystroke
    #   set regexp       # Enable regular expression mode for find (Ctrl+r to disable)
    #   set smarthome    # Home key jumps to first non-whitespace character
    #   set tabsize 4    # Insert 4 spaces per tab
    #   set tabstospaces # Tab key inserts spaces (Ctrl+t for verbatim mode)
    #   set numbercolor blue,black
    #   set statuscolor black,yellow
    #   set titlecolor black,magenta
    #   include "${pkgs.nano}/share/nano/extra/*.nanorc"
    # '';
  };

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
    "d /mnt/snapshot/${username} 0755 ${username} users"
  ];

  system.activationScripts.diff = {
    supportsDryActivation = true;
    text = ''
      ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
    '';
  };
  system.stateVersion = stateVersion;
}
