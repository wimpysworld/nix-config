{
  catppuccinPalette,
  config,
  inputs,
  isLima,
  isWorkstation,
  lib,
  outputs,
  pkgs,
  stateVersion,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  imports = [
    # Custom Home Manager modules go here
    #outputs.homeManagerModules.mymodule

    # Modules exported from other flakes:
    inputs.catppuccin.homeModules.catppuccin
    inputs.sops-nix.homeManagerModules.sops
    inputs.mac-app-util.homeManagerModules.default
    inputs.nix-index-database.homeModules.nix-index
    inputs.vscode-server.nixosModules.home
    ./_mixins/development
    ./_mixins/filesync
    ./_mixins/scripts
    ./_mixins/services
    ./_mixins/terminal
    ./_mixins/users
  ]
  ++ lib.optional isWorkstation ./_mixins/desktop;

  # Enable the Catppuccin theme
  catppuccin = {
    accent = catppuccinPalette.accent;
    flavor = catppuccinPalette.flavor;
    fish.enable = config.programs.fish.enable;
    zsh-syntax-highlighting.enable = config.programs.zsh.enable;
  };

  home = {
    inherit stateVersion;
    inherit username;
    homeDirectory =
      if isDarwin then
        "/Users/${username}"
      else if isLima then
        "/home/${username}.linux"
      else
        "/home/${username}";
    file.".config/fontconfig/fonts.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <match target="font">
          <edit name="antialias" mode="assign">
            <bool>true</bool>
          </edit>
          <edit name="hinting" mode="assign">
            <bool>true</bool>
          </edit>
          <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
          </edit>
          <edit name="rgba" mode="assign">
            <const>rgb</const>
          </edit>
          <edit name="lcdfilter" mode="assign">
            <const>lcddefault</const>
          </edit>
        </match>
      </fontconfig>
    '';
    packages =
      with pkgs;
      [
        nerd-fonts.fira-code
        font-awesome
        noto-fonts-color-emoji
        noto-fonts-monochrome-emoji
        symbola
        work-sans
      ]
      ++ lib.optionals isWorkstation [
        bebas-neue-2014-font
        bebas-neue-pro-font
        bebas-neue-rounded-font
        bebas-neue-semi-rounded-font
        bw-fusiona-font
        boycott-font
        commodore-64-pixelized-font
        corefonts
        digital-7-font
        dirty-ego-font
        fira-go
        fira-sans
        fixedsys-core-font
        fixedsys-excelsior-font
        impact-label-font
        lato
        liberation_ttf
        mocha-mattari-font
        nerd-fonts.space-mono
        nerd-fonts.symbols-only
        poppins-font
        source-serif
        spaceport-2006-font
        ubuntu-classic
        unscii
        zx-spectrum-7-font
      ];
    sessionVariables = {
      COLORTERM = "truecolor";
      EDITOR = "micro";
      SUDO_EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [
          "Source Serif"
          "Noto Color Emoji"
        ];
        sansSerif = [
          "Work Sans"
          "Noto Color Emoji"
        ];
        monospace = [
          "FiraCode Nerd Font Mono"
          "Font Awesome 6 Free"
          "Font Awesome 6 Brands"
          "Symbola"
          "Noto Emoji"
        ];
        emoji = [
          "Noto Color Emoji"
        ];
      };
    };
  };

  # Workaround home-manager bug with flakes
  # - https://github.com/nix-community/home-manager/issues/2033
  news.display = "silent";

  nixpkgs = {
    overlays = [
      # Overlays defined via overlays/default.nix and pkgs/default.nix
      outputs.overlays.localPackages
      outputs.overlays.modifiedPackages
      outputs.overlays.unstablePackages
    ];
    # Configure your nixpkgs instance
    config = {
      allowUnfree = true;
    };
  };

  programs = {
    bash = {
      initExtra = lib.mkIf config.programs.nh.enable ''
        # Set nh search to use the stable channel
        export NH_SEARCH_CHANNEL="$(noughty channel 2>/dev/null || echo nixos-unstable)"
      '';
    };
    fish = {
      enable = true;
      shellInit = lib.mkIf config.programs.nh.enable ''
        set fish_greeting ""
        # Set nh search to use the stable channel
        set -gx NH_SEARCH_CHANNEL (noughty channel 2>/dev/null; or echo nixos-unstable)
      '';
    };
    home-manager.enable = true;
    info.enable = true;
    nh = {
      enable = true;
      clean = {
        dates = "weekly";
        enable = true;
        extraArgs = "--keep 2 --keep-since 5d";
      };
    };
    nix-index.enable = true;
    zsh = {
      initContent = lib.mkIf config.programs.nh.enable (
        lib.mkOrder 500 ''
          # Set nh search to use the stable channel
          export NH_SEARCH_CHANNEL="$(noughty channel 2>/dev/null || echo nixos-unstable)"
        ''
      );
    };
  };

  # https://dl.thalheim.io/
  sops = {
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../secrets/secrets.yaml;
  };

  # Fix sops-nix launchd service PATH on Darwin
  launchd.agents.sops-nix = lib.mkIf isDarwin {
    enable = true;
    config = {
      EnvironmentVariables = {
        PATH = lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  systemd = lib.mkIf isLinux {
    user = {
      # Nicely reload system units when changing configs
      startServices = "sd-switch";
      systemctlPath = "${pkgs.systemd}/bin/systemctl";
      # Create age keys directory for SOPS
      tmpfiles = {
        rules = [
          "d ${config.home.homeDirectory}/.config/sops/age 0755 ${username} users - -"
        ];
      };
    };
  };

  xdg = {
    enable = isLinux;
    desktopEntries = lib.mkIf isLinux {
      cups = {
        name = "Manage Printing";
        noDisplay = true;
      };
      fish = {
        name = "fish";
        noDisplay = true;
      };
    };
    userDirs = {
      # Do not create XDG directories for LIMA; it is confusing
      enable = isLinux && !isLima;
      createDirectories = lib.mkDefault true;
      extraConfig = {
        XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
      };
    };
  };
}
