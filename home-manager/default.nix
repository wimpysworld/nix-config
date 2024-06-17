{ config, desktop, hostname, inputs, lib, outputs, pkgs, stateVersion, username, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
  isLima = builtins.substring 0 5 hostname == "lima-";
  isWorkstation = if (desktop != null) then true else false;
  isStreamstation = if (hostname == "phasma" || hostname == "vader") then true else false;
in
{
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Modules exported from other flakes:
    inputs.catppuccin.homeManagerModules.catppuccin
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-index-database.hmModules.nix-index
  ]
  ++ lib.optional (builtins.pathExists (./. + "/_mixins/users/${username}")) ./_mixins/users/${username}
  ++ lib.optional (builtins.pathExists (./. + "/_mixins/hosts/${hostname}")) ./_mixins/hosts/${hostname}
  ++ lib.optional (isWorkstation) ./_mixins/desktop;

  catppuccin = {
    accent = "blue";
    flavor = "mocha";
  };

  home = {
    inherit stateVersion;
    inherit username;
    homeDirectory = if isDarwin then "/Users/${username}" else if isLima then "/home/${username}.linux" else "/home/${username}";

    file = {
      "${config.xdg.configHome}/fastfetch/config.jsonc".text = builtins.readFile ./_mixins/configs/fastfetch.jsonc;
    };
    file = {
      "${config.xdg.configHome}/rio/themes/catppuccin-mocha.toml".text = builtins.readFile ./_mixins/configs/rio-catppuccin-mocha.toml;
    };
    file = {
      "${config.xdg.configHome}/yazi/keymap.toml".text = builtins.readFile ./_mixins/configs/yazi-keymap.toml;
    };
    file = {
      "${config.xdg.configHome}/yazi/theme.toml".text = builtins.readFile ./_mixins/configs/yazi-theme.toml;
    };
    file = {
      "${config.xdg.configHome}/halloy/themes/harmony-dark.yaml".text = builtins.readFile ./_mixins/configs/harmony-dark.yaml;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/build-home.fish".text = builtins.readFile ./_mixins/configs/build-home.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/switch-home.fish".text = builtins.readFile ./_mixins/configs/switch-home.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/help.fish".text = builtins.readFile ./_mixins/configs/help.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/h.fish".text = builtins.readFile ./_mixins/configs/h.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/lima-create.fish".text = builtins.readFile ./_mixins/configs/lima-create.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/gpg-restore.fish".text = builtins.readFile ./_mixins/configs/gpg-restore.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/get-nix-hash.fish".text = builtins.readFile ./_mixins/configs/get-nix-hash.fish;
    };
    file = {
      ".hidden".text = ''snap'';
    };

    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })
      ubuntu_font_family
      work-sans
      asciicam # Terminal webcam
      asciinema-agg # Convert asciinema to .gif
      asciinema # Terminal recorder
      bandwhich # Modern Unix `iftop`
      bmon # Modern Unix `iftop`
      breezy # Terminal bzr client
      #butler # Terminal Itch.io API client
      chafa # Terminal image viewer
      chroma # Code syntax highlighter
      clinfo # Terminal OpenCL info
      cpufetch # Terminal CPU info
      croc # Terminal file transfer
      curlie # Terminal HTTP client
      dconf2nix # Nix code from Dconf files
      difftastic # Modern Unix `diff`
      dogdns # Modern Unix `dig`
      dotacat # Modern Unix lolcat
      dua # Modern Unix `du`
      duf # Modern Unix `df`
      du-dust # Modern Unix `du`
      editorconfig-core-c # EditorConfig Core
      entr # Modern Unix `watch`
      fastfetch # Modern Unix system info
      fd # Modern Unix `find`
      frogmouth # Terminal mardown viewer
      glow # Terminal Markdown renderer
      gping # Modern Unix `ping`
      h # Modern Unix autojump for git projects
      hexyl # Modern Unix `hexedit`
      hr # Terminal horizontal rule
      httpie # Terminal HTTP client
      hyperfine # Terminal benchmarking
      iperf3 # Terminal network benchmarking
      halloy # Terminal IRC
      jpegoptim # Terminal JPEG optimizer
      jiq # Modern Unix `jq`
      lima-bin # Terminal VM manager
      mdp # Terminal Markdown presenter
      mtr # Modern Unix `traceroute`
      neo-cowsay # Terminal ASCII cows
      netdiscover # Modern Unix `arp`
      nixpkgs-review # Nix code review
      nix-prefetch-scripts # Nix code fetcher
      nurl # Nix URL fetcher
      nyancat # Terminal rainbow spewing feline
      onefetch # Terminal git project info
      optipng # Terminal PNG optimizer
      procs # Modern Unix `ps`
      quilt # Terminal patch manager
      rclone # Modern Unix `rsync`
      rsync # Traditional `rsync`
      sd # Modern Unix `sed`
      speedtest-go # Terminal speedtest.net
      terminal-parrot # Terminal ASCII parrot
      tldr # Modern Unix `man`
      tokei # Modern Unix `wc` for code
      ueberzugpp # Terminal image viewer integration
      unzip # Terminal ZIP extractor
      upterm # Terminal sharing
      wget # Terminal HTTP client
      wget2 # Terminal HTTP client
      wthrr # Modern Unix weather
      wormhole-william # Terminal file transfer
      yq-go # Terminal `jq` for YAML
    ] ++ lib.optionals (isStreamstation) [
      # Deckmaster and the utilities I bind to the Stream Deck
      alsa-utils
      bc
      deckmaster
      hueadm
      notify-desktop
      obs-cli
      obs-cmd
      piper-tts
      playerctl
      pulsemixer
    ] ++ lib.optionals isLinux [
      figlet # Terminal ASCII banners
      iw # Terminal WiFi info
      lurk # Modern Unix `strace`
      pciutils # Terminal PCI info
      psmisc # Traditional `ps`
      ramfetch # Terminal system info
      s-tui # Terminal CPU stress test
      snapcraft
      stress-ng # Terminal CPU stress test
      usbutils # Terminal USB info
      wavemon # Terminal WiFi monitor
      writedisk # Modern Unix `dd`
      zsync # Terminal file sync; FTBFS on aarch64-darwin
    ] ++ lib.optionals isDarwin [
      m-cli # Terminal Swiss Army Knife for macOS
      nh
      coreutils
    ];
    sessionVariables = {
      EDITOR = "micro";
      MANPAGER = "sh -c 'col --no-backspaces --spaces | bat --language man'";
      MANROFFOPT = "-c";
      PAGER = "bat";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  fonts.fontconfig.enable = true;

  # Workaround home-manager bug with flakes
  # - https://github.com/nix-community/home-manager/issues/2033
  news.display = "silent";

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # Add overlays exported from other flakes:

    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    package = pkgs.unstable.nix;
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      netrc-file = "${config.home.homeDirectory}/.local/share/flakehub/netrc";
      extra-trusted-substituters = "https://cache.flakehub.com/";
      extra-trusted-public-keys = "cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE= cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU=";
      # Avoid unwanted garbage collection when using nix-direnv
      keep-outputs = true;
      keep-derivations = true;
      warn-dirty = false;
    };
  };

  programs = {
    aria2.enable = true;
    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      flags = [
        "--disable-up-arrow"
      ];
      package = pkgs.atuin;
      settings = {
        auto_sync = true;
        dialect = "uk";
        key_path = config.sops.secrets.atuin_key.path;
        show_preview = true;
        style = "compact";
        sync_frequency = "1h";
        sync_address = "https://api.atuin.sh";
        update_check = false;
      };
    };
    bat = {
      catppuccin.enable = true;
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batgrep
        batwatch
        prettybat
      ];
      config = {
        style = "plain";
      };
    };
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
          list = [ "/dev/loop" ];
          regex = true;
          case_sensitive = false;
          whole_word = false;
        };
        flags = {
          dot_marker = false;
          enable_gpu_memory = true;
          group_processes = true;
          hide_table_gap = true;
          mem_as_value = true;
          tree = true;
        };
      };
    };
    cava = {
      enable = isLinux;
      settings = {
        color = {
          gradient = 1;
          gradient_count = 8;
          gradient_color_1 = "'#59cc33'";
          gradient_color_2 = "'#80cc33'";
          gradient_color_3 = "'#a6cc33'";
          gradient_color_4 = "'#cccc33'";
          gradient_color_5 = "'#cca633'";
          gradient_color_6 = "'#cc8033'";
          gradient_color_7 = "'#cc5933'";
          gradient_color_8 = "'#cc3333'";
        };
      };
    };
    dircolors = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv = {
        enable = true;
      };
    };
    eza = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
      git = true;
      icons = true;
    };
    fish = {
      enable = true;
      shellAliases = {
        banner = lib.mkIf isLinux "${pkgs.figlet}/bin/figlet";
        banner-color = lib.mkIf isLinux  "${pkgs.figlet}/bin/figlet $argv | ${pkgs.dotacat}/bin/dotacat";
        brg = "${pkgs.bat-extras.batgrep}/bin/batgrep";
        cat = "${pkgs.bat}/bin/bat --paging=never";
        dadjoke = ''${pkgs.curlMinimal}/bin/curl --header "Accept: text/plain" https://icanhazdadjoke.com/'';
        dmesg = "${pkgs.util-linux}/bin/dmesg --human --color=always";
        neofetch = "${pkgs.fastfetch}/bin/fastfetch";
        glow = "${pkgs.glow}/bin/glow --pager";
        hr = ''${pkgs.hr}/bin/hr "─━"'';
        htop = "${pkgs.bottom}/bin/btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        ip = "${pkgs.iproute2}/bin/ip --color --brief";
        less = "${pkgs.bat}/bin/bat";
        lolcat = "${pkgs.dotacat}/bin/dotacat";
        make-lima-builder = "lima-create builder";
        make-lima-default = "lima-create default";
        moon = "${pkgs.curlMinimal}/bin/curl -s wttr.in/Moon";
        more = "${pkgs.bat}/bin/bat";
        checkip = "${pkgs.curlMinimal}/bin/curl -s ifconfig.me/ip";
        parrot = "${pkgs.terminal-parrot}/bin/terminal-parrot -delay 50 -loops 7";
        ruler = ''${pkgs.hr}/bin/hr "╭─³⁴⁵⁶⁷⁸─╮"'';
        screenfetch = "${pkgs.fastfetch}/bin/fastfetch";
        speedtest = "${pkgs.speedtest-go}/bin/speedtest-go";
        store-path = "${pkgs.coreutils-full}/bin/readlink (${pkgs.which}/bin/which $argv)";
        top = "${pkgs.bottom}/bin/btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        tree = "${pkgs.eza}/bin/eza --tree";
        wormhole = "${pkgs.wormhole-william}/bin/wormhole-william";
        weather = "${pkgs.wthrr}/bin/wthrr auto -u f,24h,c,mph -f d,w";
        weather-home = "${pkgs.wthrr}/bin/wthrr basingstoke -u f,24h,c,mph -f d,w";
      };
    };
    fzf = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
    };
    gh = {
      enable = true;
      extensions = with pkgs; [ gh-markdown-preview ];
      settings = {
        editor = "micro";
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
    git = {
      enable = true;
      aliases = {
        ci = "commit";
        cl = "clone";
        co = "checkout";
        purr = "pull --rebase";
        dlog = "!f() { GIT_EXTERNAL_DIFF=difft git log -p --ext-diff $@; }; f";
        dshow = "!f() { GIT_EXTERNAL_DIFF=difft git show --ext-diff $@; }; f";
        fucked = "reset --hard";
        graph  = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
      difftastic = {
        display = "side-by-side-show-both";
        enable = true;
      };
      extraConfig = {
        advice = {
          statusHints = false;
        };
        color = {
          branch = false;
          diff = false;
          interactive = true;
          log = false;
          status = true;
          ui = false;
        };
        core = {
          pager = "bat";
        };
        push = {
          default = "matching";
        };
        pull = {
          rebase = false;
        };
        init = {
          defaultBranch = "main";
        };
      };
      ignores = [
        "*.log"
        "*.out"
        ".DS_Store"
        "bin/"
        "dist/"
        "result"
      ];
    };
    gitui = {
      enable = true;
      theme = ''
      (
        selected_tab: Reset,
        command_fg: Black,
        selection_bg: Blue,
        selection_fg: White,
        cmdbar_bg: Yellow,
        cmdbar_extra_lines_bg: Yellow,
        disabled_fg: DarkGray,
        diff_line_add: Green,
        diff_line_delete: Red,
        diff_file_added: LightGreen,
        diff_file_removed: LightRed,
        diff_file_moved: LightMagenta,
        diff_file_modified: Yellow,
        commit_hash: Magenta,
        commit_time: LightCyan,
        commit_author: Green,
        danger_fg: Red,
        push_gauge_bg: Blue,
        push_gauge_fg: Reset,
        tag_fg: LightMagenta,
        branch_fg: LightYellow,
      )
      '';
    };
    gpg.enable = true;
    home-manager.enable = true;
    info.enable = true;
    jq.enable = true;
    micro = {
      enable = true;
      settings = {
        autosu = true;
        colorscheme = "simple";
        diffgutter = true;
        paste = true;
        rmtrailingws = true;
        savecursor = true;
        saveundo = true;
        scrollbar = true;
        scrollbarchar = "•";
        scrollmargin = 4;
        scrollspeed = 1;
      };
    };
    nix-index.enable = true;
    powerline-go = {
      enable = true;
      settings = {
        cwd-max-depth = 5;
        cwd-max-dir-size = 12;
        max-width = 60;
      };
    };
    rio = {
      enable = true;
      package = pkgs.rio;
      settings = {
        # Whenever the key binding `OpenConfigEditor` is triggered it will
        # use the value of the editor along with the rio configuration path.
        editor = "micro";
        # Default cursor is Block; other available options are: '_' and '|'
        cursor = "▇";
        # Blinking Cursor; false by default
        blinking-cursor = true;
        # Ignore theme selection foreground color; false by default
        ignore-selection-foreground-color = false;
        theme = "catppuccin-mocha";
        # define x axis padding (default is 0)
        padding-x = 2;
        # Window configuration
        # • width - define the intial window width.
        # • height - define the inital window height.
        # • mode - define how the window will be created
        #     - "Windowed" (default) is based on width and height
        #     - "Maximized" window is created with maximized
        #     - "Fullscreen" window is created with fullscreen
        # • background-opacity - Set background opacity
        # • foreground-opacity - Set foreground opacity
        # • blur - Set blur on the window background. Changing this config requires restarting Rio to take effect.
        # • decorations - Set window decorations, options: "Enabled", "Disabled", "Transparent", "Buttonless"
        window.width = 1024;
        window.height = 768;
        window.mode = "Windowed";
        window.foreground-opacity = 1.0;
        window.background-opacity = 1.0;
        window.blur = false;
        window.decorations = "Enabled";
        fonts.family = "FiraCode Nerd Font Mono";
        fonts = {
          extras = [ {
            family = "Symbols Nerd Font Mono";
          } ];
	      };
        fonts.size = 25;
        fonts.regular.family = "FiraCode Nerd Font";
        fonts.regular.style = "Medium";
        fonts.regular.weight = 500;
        fonts.bold.family = "FiraCode Nerd Font";
        fonts.bold.style = "Bold";
        fonts.bold.weight = 800;
        fonts.italic.family = "FiraCode Nerd Font";
        fonts.italic.style = "italic";
        fonts.italic.weight = 400;
        fonts.bold-italic.family = "FiraCode Nerd Font";
        fonts.bold-italic.style = "italic";
        fonts.bold-italic.weight = 800;
      };
    };
    ripgrep = {
      arguments = [
        "--colors=line:style:bold"
        "--max-columns-preview"
        "--smart-case"
      ];
      enable = true;
    };
    tmate.enable = true;
    tmux = {
      aggressiveResize = true;
      baseIndex = 1;
      clock24 = true;
      historyLimit = 50000;
      enable = true;
      escapeTime = 0;
      extraConfig = ''
        set -g status on
        # Increase tmux messages display duration from 750ms to 4s
        set -g display-time 4000
        # Refresh 'status-left' and 'status-right' more often, from every 15s to 5s
        set -g status-interval 5
        # Focus events enabled for terminals that support them
        set -g focus-events on
        # Status at the top
        set -g status-position top
        # | and - for splitting panes:
        bind | split-window -h
        bind "\\" split-window -fh
        bind - split-window -v
        bind _ split-window -fv
        unbind '"'
        unbind %
        # reload config file
        bind r source-file ~/.config/tmux/tmux.conf; display-message "Config reloaded"
        # Fast pant-switching using Alt-arrow without prefix
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D
      '';
      keyMode = "emacs";
      mouse = true;
      newSession = false;
      sensibleOnTop = true;
      shortcut = "a";
      terminal = "tmux-256color";
    };
    yazi = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      package = pkgs.yazi;
      settings = {
        manager = {
          show_hidden = false;
          show_symlink = true;
          sort_by = "natural";
          sort_dir_first = true;
          sort_sensitive = false;
          sort_reverse = false;
        };
      };
    };
    yt-dlp = {
      enable = true;
      package = pkgs.yt-dlp;
      settings ={
        audio-format = "best";
        audio-quality = 0;
        embed-chapters = true;
        embed-metadata = true;
        embed-subs = true;
        embed-thumbnail = true;
        remux-video = "aac>m4a/mov>mp4/mkv";
        sponsorblock-mark = "sponsor";
        sub-langs = "all";
      };
    };
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      # Replace cd with z and add cdi to access zi
      options = [
        "--cmd cd"
      ];
    };
  };

  services = {
    gpg-agent = {
      enable = isLinux;
      enableSshSupport = true;
      pinentryPackage = pkgs.pinentry-curses;
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkIf isLinux "sd-switch";

  xdg = {
    enable = isLinux;
    userDirs = {
      enable = isLinux;
      createDirectories = lib.mkDefault true;
      extraConfig = {
        XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
      };
    };
  };
}
