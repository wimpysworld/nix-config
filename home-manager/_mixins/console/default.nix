{ pkgs, ... }: {
  imports = [
    ./fish.nix
    ./git.nix
    ./neofetch.nix
    ./xdg.nix
  ];

  home = {
    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages = with pkgs; [
      alejandra       # Nix code formatter
      asciinema       # Terminal recorder
      bmon            # Modern Unix `iftop`
      breezy          # Terminal bzr client
      btop            # Modern Unix `top`
      chafa           # Terminal image viewer
      croc            # Terminal file transfer
      curlie          # Terminal HTTP client
      dconf2nix       # Nix code from Dconf files
      deadnix         # Nix dead code scanner
      debootstrap     # Terminal Debian installer
      diffr           # Modern Unix `diff`
      difftastic      # Modern Unix `diff`
      dive            # Container analyzer
      dogdns          # Modern Unix `dig`
      duf             # Modern Unix `df`
      du-dust         # Modern Unix `du`
      fd              # Modern Unix `find`
      glow            # Terminal Markdown renderer
      gping           # Modern Unix `ping`
      grype           # Container vulnerability scanner
      gtop            # Modern Unix `top`
      hexyl           # Modern Unix `hexedit`
      httpie          # Terminal HTTP client
      hueadm          # Terminal Philips Hue client
      hugo            # Terminal static site generator
      hyperfine       # Terminal benchmarking
      iperf3          # Terminal network benchmarking
      jpegoptim       # Terminal JPEG optimizer
      jiq             # Modern Unix `jq`
      lazygit         # Terminal Git client
      maestral        # Terminal Dropbox client
      mdp             # Terminal Markdown presenter
      mktorrent       # Terminal torrent creator
      most            # Modern Unix `less`
      mtr             # Modern Unix `traceroute`
      netdiscover     # Modern Unix `arp`
      nethogs         # Modern Unix `iftop`
      nixpkgs-fmt     # Nix code formmater
      nixpkgs-review  # Nix code review
      nyancat         # Terminal rainbow spewing feline
      ookla-speedtest # Terminal speedtest
      optipng         # Terminal PNG optimizer
      procs           # Modern Unix `ps`
      quilt           # Terminal patch manager
      rclone          # Terminal cloud storage client
      ripgrep         # Modern Unix `grep`
      shellcheck      # Terminal shell linter
      syft            # Container SBOM generator
      tldr            # Modern Unix `man`
      tokei           # Modern Unix `wc` for code
      wavemon         # Terminal WiFi monitor
      wmctrl          # Terminal X11 automation
      xdotool         # Terminal X11 automation
      yadm            # Terminal dot file manager
      ydotool         # Terminal automation
      yq-go           # Yerminal `jq` for YAML
      zsync           # Terminal file sync
    ];
    sessionVariables = {
      EDITOR = "nano";
      PAGER = "most";
      SYSTEMD_EDITOR = "nano";
      VISUAL = "nano";
    };
  };

  programs = {
    atuin = {
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    bat.enable = true;
    bottom = {
      enable = true;
      settings = {
        colors = {
          high_battery_color = "green";
          medium_battery_color = "yellow";
          low_battery_color = "red";
        };
        disk_filter = {
          is_list_ignored = true;
          list = ["/dev/loop"];
          regex = true;
          case_sensitive = false;
          whole_word = false;
        };
        flags = {
          dot_marker = true;
          enable_gpu_memory = true;
          group_processes = true;
          hide_table_gap = true;
          mem_as_value = true;
          tree = true;
        };
      };
    };
    command-not-found.enable = true;
    dircolors = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv = {
        enable = true;
      };
    };
    exa = {
      enable = true;
      enableAliases = true;
      icons = true;
    };
    gpg.enable = true;
    home-manager.enable = true;
    info.enable = true;
    jq.enable = true;
    micro.enable = true;
    powerline-go.enable = true;
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentryFlavor = "curses";
    };
    kbfs = {
      enable = true;
      mountPoint = "Keybase";
    };
    keybase.enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
