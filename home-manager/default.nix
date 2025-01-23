{
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
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Modules exported from other flakes:
    inputs.catppuccin.homeManagerModules.catppuccin
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-index-database.hmModules.nix-index
    ./_mixins/features
    ./_mixins/scripts
    ./_mixins/services
    ./_mixins/users
  ] ++ lib.optional isWorkstation ./_mixins/desktop;

  # Enable the Catppuccin theme
  catppuccin = {
    accent = "blue";
    flavor = "mocha";
    bat.enable = config.programs.bat.enable;
    bottom.enable = config.programs.bottom.enable;
    cava.enable = config.programs.cava.enable;
    fish.enable = config.programs.fish.enable;
    fzf.enable = config.programs.fzf.enable;
    gh-dash.enable = config.programs.gh.extensions.gh-dash;
    gitui.enable = config.programs.gitui.enable;
    micro.enable = config.programs.micro.enable;
    starship.enable = config.programs.starship.enable;
    yazi.enable = config.programs.yazi.enable;
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

    file = {
      "${config.xdg.configHome}/fastfetch/config.jsonc".text = builtins.readFile ./_mixins/configs/fastfetch.jsonc;
      "${config.xdg.configHome}/yazi/keymap.toml".text = builtins.readFile ./_mixins/configs/yazi-keymap.toml;
      "${config.xdg.configHome}/fish/functions/help.fish".text = builtins.readFile ./_mixins/configs/help.fish;
      "${config.xdg.configHome}/fish/functions/h.fish".text = builtins.readFile ./_mixins/configs/h.fish;
      ".hidden".text = ''snap'';
    };

    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages =
      with pkgs;
      [
        asciicam # Terminal webcam
        asciinema-agg # Convert asciinema to .gif
        bc # Terminal calculator
        bandwhich # Modern Unix `iftop`
        bmon # Modern Unix `iftop`
        breezy # Terminal bzr client
        chafa # Terminal image viewer
        clinfo # Terminal OpenCL info
        cpufetch # Terminal CPU info
        croc # Terminal file transfer
        curlie # Terminal HTTP client
        cyme # Modern Unix `lsusb`
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
        file # Terminal file info
        frogmouth # Terminal markdown viewer
        glow # Terminal Markdown renderer
        girouette # Modern Unix weather
        gocryptfs # Terminal encrypted filesystem
        gping # Modern Unix `ping`
        git-igitt # Modern Unix git log/graph
        h # Modern Unix autojump for git projects
        hexyl # Modern Unix `hexedit`
        hr # Terminal horizontal rule
        httpie # Terminal HTTP client
        hueadm # Terminal Philips Hue client
        hyperfine # Terminal benchmarking
        iperf3 # Terminal network benchmarking
        ipfetch # Terminal IP info
        jpegoptim # Terminal JPEG optimizer
        jiq # Modern Unix `jq`
        lastpass-cli # Terminal LastPass client
        lima-bin # Terminal VM manager
        marp-cli # Terminal Markdown presenter
        mtr # Modern Unix `traceroute`
        neo-cowsay # Terminal ASCII cows
        netdiscover # Modern Unix `arp`
        nixfmt-rfc-style # Nix code formatter
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
        timer # Terminal timer
        tldr # Modern Unix `man`
        tokei # Modern Unix `wc` for code
        ueberzugpp # Terminal image viewer integration
        unzip # Terminal ZIP extractor
        upterm # Terminal sharing
        wget # Terminal HTTP client
        wget2 # Terminal HTTP client
        wormhole-william # Terminal file transfer
        yq-go # Terminal `jq` for YAML
      ]
      ++ lib.optionals isLinux [
        figlet # Terminal ASCII banners
        iw # Terminal WiFi info
        lurk # Modern Unix `strace`
        pciutils # Terminal PCI info
        psmisc # Traditional `ps`
        ramfetch # Terminal system info
        s-tui # Terminal CPU stress test
        shellcheck # Terminal shell linter
        stress-ng # Terminal CPU stress test
        tty-clock # Terminal clock
        usbutils # Terminal USB info
        vhs # Terminal GIF recorder
        wavemon # Terminal WiFi monitor
        writedisk # Modern Unix `dd`
        zsync # Terminal file sync; FTBFS on aarch64-darwin
      ]
      ++ lib.optionals isDarwin [
        m-cli # Terminal Swiss Army Knife for macOS
        nh
        coreutils
      ];
    sessionVariables = {
      EDITOR = "micro";
      MANPAGER = "sh -c 'col --no-backspaces --spaces | bat --language man'";
      MANROFFOPT = "-c";
      MICRO_TRUECOLOR = "1";
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
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    # Configure your nixpkgs instance
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    package = pkgs.nixVersions.latest;
    settings = {
      experimental-features = "flakes nix-command";
      trusted-users = [
        "root"
        "${username}"
      ];
    };
  };

  programs = {
    aria2.enable = true;
    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      flags = [ "--disable-up-arrow" ];
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
      icons = "auto";
    };
    fish = {
      enable = true;
      shellAliases = {
        banner = lib.mkIf isLinux "${pkgs.figlet}/bin/figlet";
        banner-color = lib.mkIf isLinux "${pkgs.figlet}/bin/figlet $argv | ${pkgs.dotacat}/bin/dotacat";
        brg = "${pkgs.bat-extras.batgrep}/bin/batgrep";
        cat = "${pkgs.bat}/bin/bat --paging=never";
        clock = if isLinux then ''${pkgs.tty-clock}/bin/tty-clock -B -c -C 4 -f "%a, %d %b"'' else "";
        dadjoke = ''${pkgs.curlMinimal}/bin/curl --header "Accept: text/plain" https://icanhazdadjoke.com/'';
        dmesg = "${pkgs.util-linux}/bin/dmesg --human --color=always";
        neofetch = "${pkgs.fastfetch}/bin/fastfetch";
        glow = "${pkgs.glow}/bin/glow --pager";
        hr = ''${pkgs.hr}/bin/hr "─━"'';
        htop = "${pkgs.bottom}/bin/btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        ip = lib.mkIf isLinux "${pkgs.iproute2}/bin/ip --color --brief";
        less = "${pkgs.bat}/bin/bat";
        lm = "${pkgs.lima-bin}/bin/limactl";
        lolcat = "${pkgs.dotacat}/bin/dotacat";
        moon = "${pkgs.curlMinimal}/bin/curl -s wttr.in/Moon";
        more = "${pkgs.bat}/bin/bat";
        parrot = "${pkgs.terminal-parrot}/bin/terminal-parrot -delay 50 -loops 7";
        pq = "${pkgs.pueue}/bin/pueue";
        ruler = ''${pkgs.hr}/bin/hr "╭─³⁴⁵⁶⁷⁸─╮"'';
        screenfetch = "${pkgs.fastfetch}/bin/fastfetch";
        speedtest = "${pkgs.speedtest-go}/bin/speedtest-go";
        store-path = "${pkgs.coreutils-full}/bin/readlink (${pkgs.which}/bin/which $argv)";
        top = "${pkgs.bottom}/bin/btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        tree = "${pkgs.eza}/bin/eza --tree";
        wormhole = "${pkgs.wormhole-william}/bin/wormhole-william";
        weather = "${lib.getExe pkgs.girouette} --quiet";
        weather-home = "${lib.getExe pkgs.girouette} --quiet --location Basingstoke";
        where-am-i = "${pkgs.geoclue2}/libexec/geoclue-2.0/demos/where-am-i";
        lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
        unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
        lock-secrets = "fusermount -u ~/Vaults/Secrets";
        unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
      };
    };
    fzf = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    gh = {
      enable = true;
      extensions = with pkgs; [
        gh-dash
        gh-markdown-preview
      ];
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
        graph = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
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
    };
    gpg.enable = true;
    home-manager.enable = true;
    info.enable = true;
    jq.enable = true;
    micro = {
      enable = true;
      settings = {
        autosu = true;
        diffgutter = true;
        paste = true;
        rmtrailingws = true;
        savecursor = true;
        saveundo = true;
        scrollbar = true;
        scrollbarchar = "░";
        scrollmargin = 4;
        scrollspeed = 1;
      };
    };
    nix-index.enable = true;
    ripgrep = {
      arguments = [
        "--colors=line:style:bold"
        "--max-columns-preview"
        "--smart-case"
      ];
      enable = true;
    };
    starship = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      # https://github.com/etrigan63/Catppuccin-starship
      settings = {
        add_newline = false;
        command_timeout = 1000;
        time = {
          disabled = true;
        };
        format = lib.concatStrings [
          "[](surface1)"
          "$os"
          "[](bg:surface2 fg:surface1)"
          "$username"
          "$sudo"
          "[](bg:overlay0 fg:surface2)"
          "$hostname"
          "[](bg:mauve fg:overlay0)"
          "$directory"
          "[](fg:mauve bg:peach)"
          "$c"
          "$dart"
          "$dotnet"
          "$elixir"
          "$elm"
          "$erlang"
          "$golang"
          "$haskell"
          "$haxe"
          "$java"
          "$julia"
          "$kotlin"
          "$lua"
          "$nim"
          "$nodejs"
          "$rlang"
          "$ruby"
          "$rust"
          "$perl"
          "$php"
          "$python"
          "$scala"
          "$swift"
          "$zig"
          "$package"
          "$git_branch"
          "[](fg:peach bg:yellow)"
          "$git_status"
          "[](fg:yellow bg:teal)"
          "$container"
          "$direnv"
          "$nix_shell"
          "$cmd_duration"
          "$jobs"
          "$shlvl"
          "$status"
          "$character"
        ];
        os = {
          disabled = false;
          format = "$symbol";
          style = "";
        };
        os.symbols = {
          AlmaLinux = "[](fg:text bg:surface1)";
          Alpine = "[](fg:blue bg:surface1)";
          Amazon = "[](fg:peach bg:surface1)";
          Android = "[](fg:green bg:surface1)";
          Arch = "[󰣇](fg:sapphire bg:surface1)";
          Artix = "[](fg:sapphire bg:surface1)";
          CentOS = "[](fg:mauve bg:surface1)";
          Debian = "[](fg:red bg:surface1)";
          DragonFly = "[](fg:teal bg:surface1)";
          EndeavourOS = "[](fg:mauve bg:surface1)";
          Fedora = "[](fg:blue bg:surface1)";
          FreeBSD = "[](fg:red bg:surface1)";
          Garuda = "[](fg:sapphire bg:surface1)";
          Gentoo = "[](fg:lavender bg:surface1)";
          Illumos = "[](fg:peach bg:surface1)";
          Kali = "[](fg:blue bg:surface1)";
          Linux = "[](fg:yellow bg:surface1)";
          Macos = "[](fg:text bg:surface1)";
          Manjaro = "[](fg:green bg:surface1)";
          Mint = "[󰣭](fg:teal bg:surface1)";
          NixOS = "[](fg:sky bg:surface1)";
          OpenBSD = "[](fg:yellow bg:surface1)";
          openSUSE = "[](fg:green bg:surface1)";
          Pop = "[](fg:sapphire bg:surface1)";
          Raspbian = "[](fg:maroon bg:surface1)";
          Redhat = "[](fg:red bg:surface1)";
          RedHatEnterprise = "[](fg:red bg:surface1)";
          RockyLinux = "[](fg:green bg:surface1)";
          Solus = "[](fg:blue bg:surface1)";
          SUSE = "[](fg:green bg:surface1)";
          Ubuntu = "[](fg:peach bg:surface1)";
          Unknown = "[](fg:text bg:surface1)";
          Void = "[](fg:green bg:surface1)";
          Windows = "[󰖳](fg:sky bg:surface1)";
        };
        username = {
          aliases = {
            "martin" = "󰝴";
            "root" = "󰱯";
          };
          format = "[ $user]($style)";
          show_always = true;
          style_user = "fg:green bg:surface2";
          style_root = "fg:red bg:surface2";
        };
        sudo = {
          disabled = false;
          format = "[ $symbol]($style)";
          style = "fg:rosewater bg:surface2";
          symbol = "󰌋";
        };
        hostname = {
          disabled = false;
          style = "bg:overlay0 fg:red";
          ssh_only = false;
          ssh_symbol = " 󰖈";
          format = "[ $hostname]($style)[$ssh_symbol](bg:overlay0 fg:maroon)";
        };
        directory = {
          format = "[ $path]($style)[$read_only]($read_only_style)";
          home_symbol = "";
          read_only = " 󰈈";
          read_only_style = "bold fg:crust bg:mauve";
          style = "fg:base bg:mauve";
          truncation_length = 3;
          truncation_symbol = "…/";
        };
        # Shorten long paths by text replacement. Order matters
        directory.substitutions = {
          "Apps" = "󰵆";
          "Audio" = "";
          "Crypt" = "󰌾";
          "Desktop" = "";
          "Development" = "";
          "Documents" = "󰈙";
          "Downloads" = "󰉍";
          "Dropbox" = "";
          "Games" = "󰊴";
          "Keybase" = "󰯄";
          "Music" = "󰎄";
          "Pictures" = "";
          "Public" = "";
          "Quickemu" = "";
          "Studio" = "󰡇";
          "Vaults" = "󰌿";
          "Videos" = "";
          "Volatile" = "󱪃";
          "Websites" = "󰖟";
          "nix-config" = "󱄅";
          "Zero" = "󰎡";
        };
        # Languages
        c = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        dart = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        dotnet = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        elixir = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        elm = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        erlang = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        golang = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        haskell = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "󰲒";
        };
        haxe = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        java = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "󰬷";
        };
        julia = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        kotlin = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        lua = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        nim = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        nodejs = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        perl = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        php = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "󰌟";
        };
        python = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        rlang = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        ruby = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        rust = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        scala = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        swift = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        zig = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        package = {
          format = "[ $version]($style)";
          style = "fg:base bg:peach";
          version_format = "$raw";
        };
        git_branch = {
          format = "[ $symbol $branch]($style)";
          style = "fg:base bg:peach";
          symbol = "";
        };
        git_status = {
          format = "[ $all_status$ahead_behind]($style)";
          conflicted = "󰳤 ";
          untracked = " ";
          stashed = " ";
          modified = " ";
          staged = " ";
          renamed = " ";
          deleted = " ";
          typechanged = " ";
          # $ahead_behind is just one of these
          ahead = "󰜹";
          behind = "󰜰";
          diverged = "";
          up_to_date = "󰤓";
          style = "fg:base bg:yellow";
        };
        # "Shells"
        container = {
          format = "[ $symbol $name]($style)";
          style = "fg:base bg:teal";
          symbol = "󱋩";
        };
        direnv = {
          disabled = false;
          format = "[ $loaded]($style)";
          allowed_msg = "";
          not_allowed_msg = "";
          denied_msg = "";
          loaded_msg = "󰐍";
          unloaded_msg = "󰙧";
          style = "fg:base bg:teal";
          symbol = "";
        };
        nix_shell = {
          format = "[ $symbol]($style)";
          style = "fg:base bg:teal";
          symbol = "󱄅";
        };
        cmd_duration = {
          format = "[  $duration]($style)";
          min_time = 2500;
          min_time_to_notify = 60000;
          show_notifications = false;
          style = "fg:base bg:teal";
        };
        jobs = {
          format = "[ $symbol $number]($style)";
          style = "fg:base bg:teal";
          symbol = "󰣖";
        };
        shlvl = {
          disabled = false;
          format = "[ $symbol]($style)";
          repeat = false;
          style = "fg:surface1 bg:teal";
          symbol = "󱆃";
          threshold = 3;
        };
        status = {
          disabled = false;
          format = "$symbol";
          map_symbol = true;
          pipestatus = false;
          style = "";
          symbol = "[](fg:teal bg:pink)[  $status](fg:red bg:pink)";
          success_symbol = "[](fg:teal bg:blue)";
          not_executable_symbol = "[](fg:teal bg:pink)[  $common_meaning](fg:red bg:pink)";
          not_found_symbol = "[](fg:teal bg:pink)[ 󰩌 $common_meaning](fg:red bg:pink)";
          sigint_symbol = "[](fg:teal bg:pink)[  $signal_name](fg:red bg:pink)";
          signal_symbol = "[](fg:teal bg:pink)[ ⚡ $signal_name](fg:red bg:pink)";
        };
        character = {
          disabled = false;
          format = "$symbol";
          error_symbol = "(fg:red bg:pink)[](fg:pink) ";
          success_symbol = "[](fg:blue) ";
        };
      };
    };
    tmate.enable = true;
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
      settings = {
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
      options = [ "--cmd cd" ];
    };
  };

  services = {
    gpg-agent = lib.mkIf isLinux {
      enable = isLinux;
      enableSshSupport = true;
      pinentryPackage = pkgs.pinentry-curses;
    };
    pueue = lib.mkIf isLinux {
      enable = isLinux;
      # https://github.com/Nukesor/pueue/wiki/Configuration
      settings = {
        daemon = {
          default_parallel_tasks = 1;
          callback = "${pkgs.notify-desktop}/bin/notify-desktop \"Task {{ id }}\nCommand: {{ command }}\nPath: {{ path }}\nFinished with status '{{ result }}'\nTook: $(bc <<< \"{{end}} - {{start}}\") seconds\" --app-name=pueue";
        };
      };
    };
  };

  # https://dl.thalheim.io/
  sops = {
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../secrets/secrets.yaml;
    secrets = {
      act-env = {
        path = "${config.home.homeDirectory}/.config/act/secrets";
        sopsFile = ../secrets/act.yaml;
        mode = "0660";
      };
      asciinema.path = "${config.home.homeDirectory}/.config/asciinema/config";
      atuin_key.path = "${config.home.homeDirectory}/.local/share/atuin/key";
      gh_token = { };
      gpg_private = { };
      gpg_public = { };
      gpg_ownertrust = { };
      hueadm.path = "${config.home.homeDirectory}/.hueadm.json";
      obs_secrets = { };
      ssh_config.path = "${config.home.homeDirectory}/.ssh/config";
      ssh_key.path = "${config.home.homeDirectory}/.ssh/id_rsa";
      ssh_pub.path = "${config.home.homeDirectory}/.ssh/id_rsa.pub";
      ssh_semaphore_key.path = "${config.home.homeDirectory}/.ssh/id_rsa_semaphore";
      ssh_semaphore_pub.path = "${config.home.homeDirectory}/.ssh/id_rsa_semaphore.pub";
      transifex.path = "${config.home.homeDirectory}/.transifexrc";
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkIf isLinux "sd-switch";
  # Create age keys directory for SOPS
  systemd.user.tmpfiles = lib.mkIf isLinux {
    rules = [
      "d ${config.home.homeDirectory}/.config/sops/age 0755 ${username} users - -"
    ];
  };

  xdg = {
    enable = isLinux;
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
