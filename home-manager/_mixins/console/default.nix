{ config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
  inherit (pkgs.stdenv) isLinux;
in
{
  fonts.fontconfig.enable = true;
  home = {
    file = {
      "${config.xdg.configHome}/fastfetch/config.jsonc".text = builtins.readFile ./fastfetch.jsonc;
    };
    file = {
      "${config.xdg.configHome}/yazi/keymap.toml".text = builtins.readFile ./yazi-keymap.toml;
    };
    file = {
      "${config.xdg.configHome}/yazi/theme.toml".text = builtins.readFile ./yazi-theme.toml;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/help.fish".text = builtins.readFile ./help.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/h.fish".text = builtins.readFile ./h.fish;
    };
    file = {
      "${config.xdg.configHome}/fish/functions/builder-create.fish".text = builtins.readFile ./builder-create.fish;
    };
    file = {
      ".hidden".text = ''snap'';
    };
    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" "UbuntuMono" ]; })
      fira
      fira-go
      ubuntu_font_family
      work-sans
      asciinema # Terminal recorder
      bandwhich # Modern Unix `iftop`
      bmon # Modern Unix `iftop`
      breezy # Terminal bzr client
      butler # Terminal Itch.io API client
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
      glow # Terminal Markdown renderer
      gping # Modern Unix `ping`
      h # Modern Unix autojump for git projects
      hexyl # Modern Unix `hexedit`
      httpie # Terminal HTTP client
      hyperfine # Terminal benchmarking
      iperf3 # Terminal network benchmarking
      jpegoptim # Terminal JPEG optimizer
      jiq # Modern Unix `jq`
      lima # Terminal VM manager
      mdp # Terminal Markdown presenter
      mtr # Modern Unix `traceroute`
      neo-cowsay # Terminal ASCII cows
      netdiscover # Modern Unix `arp`
      nixpkgs-review # Nix code review
      nurl # Nix URL fetcher
      nyancat # Terminal rainbow spewing feline
      onefetch # Terminal git project info
      optipng # Terminal PNG optimizer
      procs # Modern Unix `ps`
      quilt # Terminal patch manager
      rclone # Modern Unix `rsync`
      sd # Modern Unix `sed`
      speedtest-go # Terminal speedtest.net
      tldr # Modern Unix `man`
      tokei # Modern Unix `wc` for code
      ueberzugpp # Terminal image viewer integration
      wget2 # Terminal HTTP client
      wthrr # Modern Unix weather
      wormhole-william # Terminal file transfer
      yq-go # Terminal `jq` for YAML
    ] ++ lib.optionals isLinux [
      debootstrap # Terminal Debian installer
      figlet # Terminal ASCII banners
      iw # Terminal WiFi info
      libva-utils # Terminal VAAPI info
      lurk # Modern Unix `strace`
      python310Packages.gpustat # Terminal GPU info
      ramfetch # Terminal system info
      vdpauinfo # Terminal VDPAU info
      wavemon # Terminal WiFi monitor
      zsync # Terminal file sync; FTBFS on aarch64-darwin
    ] ++ lib.optionals isDarwin [
      m-cli # Terminal Swiss Army Knife for macOS
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

  programs = {
    aria2 = {
      enable = true;
    };
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
        show_preview = true;
        style = "compact";
        sync_frequency = "1h";
        sync_address = "https://api.atuin.sh";
        update_check = false;
      };
    };
    bat = {
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
      enableAliases = true;
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
        build-home = "pushd $HOME/Zero/nix-config && home-manager build --flake $HOME/Zero/nix-config && popd";
        switch-home = "pushd $HOME/Zero/nix-config && home-manager switch -b backup --flake $HOME/Zero/nix-config && popd";
        banner = "figlet";
        banner-color = "figlet $argv | dotacat";
        brg = "batgrep";
        builder-destroy = "limactl stop builder; limactl delete builder; rm -rf $HOME/.lima/builder";
        builder-enter = "test -f $HOME/.lima/builder/lima.yaml; and limactl shell builder; or echo builder does not exist";
        builder-shell = "builder-enter";
        builder-start = "test -d $HOME/.lima/builder/lima.yaml; and limactl start builder; or echo builder does not exist";
        builder-stop = "limactl stop builder";
        cat = "bat --paging=never";
        dadjoke = ''curl --header "Accept: text/plain" https://icanhazdadjoke.com/'';
        diff = "difft";
        dmesg = "dmesg --human --color=always";
        neofetch = "fastfetch";
        glow = "glow --pager";
        htop = "btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        ip = "ip --color --brief";
        less = "bat";
        lolcat = "dotacat";
        moon = "curl -s wttr.in/Moon";
        more = "bat";
        checkip = "curl -s ifconfig.me/ip";
        screenfetch = "fastfetch";
        speedtest = "speedtest-go";
        top = "btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        tree = "eza --tree";
        wormhole = "wormhole-william";
        weather = "wthrr auto -u f,24h,c,mph -f d,w";
        weather-home = "wthrr basingstoke -u f,24h,c,mph -f d,w";
      };
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
    powerline-go = {
      enable = true;
      settings = {
        cwd-max-depth = 5;
        cwd-max-dir-size = 12;
        max-width = 60;
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
    yazi = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
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
      package = pkgs.unstable.yt-dlp;
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
    };
  };

  services = {
    gpg-agent = {
      enable = isLinux;
      enableSshSupport = true;
      pinentryFlavor = "curses";
    };
    kbfs = {
      enable = isLinux;
      mountPoint = "Keybase";
    };
    keybase = {
      enable = isLinux;
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
