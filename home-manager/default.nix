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

  catppuccin = {
    accent = "blue";
    flavor = "mocha";
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
      "${config.xdg.configHome}/gh-dash/config.yml".text = builtins.readFile ./_mixins/configs/gh-dash-catppuccin-mocha-blue.yml;
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
        asciinema # Terminal recorder
        bc # Terminal calculator
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
        cyme # Modern Unix `lsusb`
        dconf2nix # Nix code from Dconf files
        deadnix # Nix dead code finder
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
        frogmouth # Terminal mardown viewer
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
        tty-clock # Terminal clock
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
        stress-ng # Terminal CPU stress test
        usbutils # Terminal USB info
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
      catppuccin.enable = true;
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
      catppuccin.enable = true;
      # TODO: Enable when this is released:
      # https://github.com/NixOS/nixpkgs/pull/356667
      enable = false;
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
      catppuccin.enable = true;
      enable = true;
      shellAliases = {
        banner = lib.mkIf isLinux "${pkgs.figlet}/bin/figlet";
        banner-color = lib.mkIf isLinux "${pkgs.figlet}/bin/figlet $argv | ${pkgs.dotacat}/bin/dotacat";
        brg = "${pkgs.bat-extras.batgrep}/bin/batgrep";
        cat = "${pkgs.bat}/bin/bat --paging=never";
        clock = ''${pkgs.tty-clock}/bin/tty-clock -B -c -C 4 -f "%a, %d %b"'';
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
      catppuccin.enable = true;
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
      catppuccin.enable = true;
      enable = true;
    };
    gpg.enable = true;
    home-manager.enable = true;
    info.enable = true;
    jq.enable = true;
    micro = {
      catppuccin.enable = true;
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
  neovim = {
      enable = true;
      catppuccin.enable = true;
      plugins = with pkgs.vimPlugins; [
        vim-rsi
        packer-nvim
      ];
      extraLuaConfig = ''
      -- Force insert mode and hide mode display
      vim.api.nvim_create_autocmd({"VimEnter", "BufRead", "BufNewFile", "BufEnter", "ModeChanged"}, {
        pattern = "*",
        callback = function()
          vim.cmd('startinsert')
          vim.api.nvim_set_option('showmode', false)
        end
      })

      -- Make sure visual mode always returns to insert
      vim.api.nvim_create_autocmd('ModeChanged', {
        pattern = '[vV\x16]*:*',
        callback = function()
          vim.cmd('startinsert')
        end
      })

      -- Force insert mode on mode switch attempts
      vim.keymap.set('n', '<Esc>', 'i', { noremap = true })
      vim.keymap.set('v', '<Esc>', 'i', { noremap = true })
      vim.keymap.set('n', 'i', 'i', { noremap = true })
      vim.keymap.set('n', 'a', 'i', { noremap = true })

      -- CUA keybindings with forced quit
      local opts = { noremap = true, silent = true }
      vim.keymap.set('i', '<C-s>', '<Cmd>w<CR>', opts)
      -- Quit, but check for unsaved changes
      vim.keymap.set('i', '<C-q>', function()
          if vim.fn.getbufinfo('%')[1].changed == 1 then
              local choice = vim.fn.confirm("Save changes before quitting?", "&Yes\n&No\n&Cancel", 1)
              if choice == 1 then     -- Yes
                  vim.cmd('wa')
                  vim.cmd('qa')
              elseif choice == 2 then -- No
                  vim.cmd('qa!')
              end
              -- If choice == 3 (Cancel), do nothing
          else
              vim.cmd('qa')
          end
      end, opts)
      vim.keymap.set('i', '<C-z>', '<C-o>u', opts)
      vim.keymap.set('i', '<C-y>', '<C-o><C-r>', opts)
      vim.keymap.set('i', '<C-v>', '<C-r>+', opts)
      -- Replace the Ctrl+C mappings with:
      vim.keymap.set('i', '<C-c>', '<C-o>yy<Esc>i', opts)
      vim.keymap.set('v', '<C-c>', 'y<Esc>i', opts)
      vim.keymap.set('i', '<C-x>', 'd', opts)

      -- Shift + Arrow selection
      vim.keymap.set('i', '<S-Left>', '<C-o>v0', opts)
      vim.keymap.set('i', '<S-Right>', '<C-o>v$', opts)
      vim.keymap.set('i', '<S-Up>', '<Up><C-o>v', opts)
      vim.keymap.set('i', '<S-Down>', '<Down><C-o>v', opts)
      vim.keymap.set('v', '<S-Left>', '<Left>', opts)
      vim.keymap.set('v', '<S-Right>', '<Right>', opts)
      vim.keymap.set('v', '<S-Up>', '<Up>', opts)
      vim.keymap.set('v', '<S-Down>', '<Down>', opts)
      -- Make sure Escape returns to insert mode
      vim.keymap.set('v', '<Esc>', '<Esc>i', opts)

      -- Disable Shift + Arrow page movement
      vim.keymap.set('i', '<S-PageUp>', '<PageUp>', opts)
      vim.keymap.set('i', '<S-PageDown>', '<PageDown>', opts)
      vim.keymap.set('i', '<S-Up>', '<Up><C-o>v', opts) -- Ensure these only do selection
      vim.keymap.set('i', '<S-Down>', '<Down><C-o>v', opts)

      -- Map actual page movement to PageUp/PageDown
      vim.keymap.set('i', '<PageUp>', '<C-o><C-b>', opts)
      vim.keymap.set('i', '<PageDown>', '<C-o><C-f>', opts)

      -- Search functionality (Ctrl+F)
      vim.keymap.set('i', '<C-f>', function()
          local current_pos = vim.fn.getcurpos()
          vim.cmd('normal! i')  -- Ensure we're in insert mode
          vim.fn.feedkeys('/', 'n')  -- Start search mode
          -- Setup autocmd to return to insert mode when search is done
          vim.api.nvim_create_autocmd('CmdlineLeave', {
              pattern = '/',
              once = true,
              callback = function()
                  vim.schedule(function()
                      vim.cmd('startinsert')
                      -- Restore cursor position if search was cancelled
                      if vim.fn.mode() == 'n' then
                          vim.fn.setpos('.', current_pos)
                          vim.cmd('startinsert')
                      end
                  end)
              end
          })
      end, opts)

      -- Make sure search highlighting can be cleared
      vim.keymap.set('i', '<Esc>', function()
          vim.cmd('nohlsearch')
          vim.cmd('startinsert')
      end, opts)

      -- Basic settings
      vim.opt.mouse = 'a'
      vim.opt.mousemodel = 'popup'
      vim.opt.number = true
      vim.opt.relativenumber = false
      vim.opt.wrap = false
      vim.opt.clipboard = 'unnamedplus'
      '';
    };
    nix-index.enable = true;
    powerline-go = {
      enable = false;
      settings = {
        cwd-max-depth = 5;
        cwd-max-dir-size = 12;
        theme = "gruvbox";
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
    starship = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      catppuccin.enable = true;
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
    tmux = {
      aggressiveResize = true;
      baseIndex = 1;
      catppuccin.enable = true;
      clock24 = true;
      historyLimit = 50000;
      enable = true;
      escapeTime = 0;
      extraConfig = ''
        set -g @catppuccin_window_status_icon_enable "yes"
        set -g @catppuccin_icon_window_last "󰖰"
        set -g @catppuccin_icon_window_current "󰖯"
        set -g @catppuccin_icon_window_zoom "󰁌"
        set -g @catppuccin_icon_window_mark "󰃀"
        set -g @catppuccin_icon_window_silent "󰂛"
        set -g @catppuccin_icon_window_activity "󱅫"
        set -g @catppuccin_icon_window_bell "󰂞"
        set -g @catppuccin_status_background "theme"

        set -g @catppuccin_window_left_separator ""
        set -g @catppuccin_window_right_separator " "
        set -g @catppuccin_window_middle_separator " █"
        set -g @catppuccin_window_number_position "right"

        set -g @catppuccin_window_default_fill "number"
        set -g @catppuccin_window_default_text "#W"

        set -g @catppuccin_window_current_fill "number"
        set -g @catppuccin_window_current_text "#W"

        set -g @catppuccin_status_modules_right "directory user host session"
        set -g @catppuccin_status_left_separator  " "
        set -g @catppuccin_status_right_separator ""
        set -g @catppuccin_status_fill "icon"
        set -g @catppuccin_status_connect_separator "no"

        set -g @catppuccin_directory_text "#{pane_current_path}"
        # Status at the top
        set -g status on
        set -g status-position top
        # Increase tmux messages display duration from 750ms to 4s
        set -g display-time 4000
        # Refresh 'status-left' and 'status-right' more often, from every 15s to 5s
        set -g status-interval 5
        # Focus events enabled for terminals that support them
        set -g focus-events on
        # | and - for splitting panes:
        bind | split-window -h
        bind "\\" split-window -fh
        bind - split-window -v
        bind _ split-window -fv
        unbind '"'
        unbind %
        # reload config file
        bind r source-file ~/.config/tmux/tmux.conf
        # Fast pant-switching using Alt-arrow without prefix
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D
      '';
      keyMode = "emacs";
      mouse = true;
      newSession = false;
      #sensibleOnTop = true;
      shortcut = "a";
      terminal = "tmux-256color";
    };
    yazi = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      catppuccin.enable = true;
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
    pueue = {
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
  sops = lib.mkIf (username == "martin") {
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../secrets/secrets.yaml;
    secrets = {
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
