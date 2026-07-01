{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  shellAliases = {
    dmesg = "${pkgs.util-linux}/bin/dmesg --human --color=always";
    duf = "${pkgs.duf}/bin/duf --theme ansi";
    egrep = "${pkgs.gnugrep}/bin/egrep --color=auto";
    fgrep = "${pkgs.gnugrep}/bin/fgrep --color=auto";
    grep = "${pkgs.gnugrep}/bin/grep --color=auto";
    lsusb = "${pkgs.cyme}/bin/cyme --headings";
    micro = "fresh";
    nano = "fresh";
    rsync-copy = "${pkgs.rsync}/bin/rsync --archive --block-size=131072 --human-readable --info=progress2 --inplace --no-compress --partial --stats";
    rsync-mirror = "${pkgs.rsync}/bin/rsync --archive --block-size=131072 --delete --human-readable --info=progress2 --no-compress --inplace --partial --stats";
    speedtest = "${pkgs.speedtest-go}/bin/speedtest-go";
  }
  // lib.optionalAttrs host.is.linux {
    lsusb = "${pkgs.usbutils}/bin/lsusb";
  }
  // lib.optionalAttrs host.is.workstation {
    banner = "${pkgs.figlet}/bin/figlet";
    banner-color = "${pkgs.figlet}/bin/figlet $argv | ${pkgs.dotacat}/bin/dotacat";
    clock = "${pkgs.clock-rs}/bin/clock-rs --blink --color blue --hide-seconds";
    dadjoke = ''${pkgs.curlMinimal}/bin/curl --header "Accept: text/plain" https://icanhazdadjoke.com/'';
    hr = ''${pkgs.hr}/bin/hr "─━"'';
    lolcat = "${pkgs.dotacat}/bin/dotacat";
    moon = "${pkgs.curlMinimal}/bin/curl -s wttr.in/Moon";
    ruler = ''${pkgs.hr}/bin/hr "╭─³⁴⁵⁶⁷⁸─╮"'';
    weather = "${lib.getExe pkgs.girouette} --quiet";
    wormhole = "${pkgs.wormhole-rs}/bin/wormhole-rs";
  };
in
{
  imports = [
    ./bat.nix # Modern Unix `cat`
    ./bottom.nix # Modern Unix `top`
    ./btop.nix # Modern Unix `htop`
    ./cava.nix # Terminal audio visualizer
    ./concord.nix # Terminal Discord client
    ./dircolors.nix # Terminal colors
    ./eza.nix # Modern Unix `ls`
    ./fastfetch.nix # Modern Unix `neofetch`
    ./fd.nix # Modern Unix `find`
    ./fresh.nix # Terminal text editor
    ./fzf.nix # Terminal fuzzy finder
    ./gpg.nix # Terminal GPG
    ./herdr.nix # Terminal workspace manager for AI coding agents
    ./iamb.nix # Terminal Matrix client
    ./mpv.nix # Terminal media player
    ./pueue.nix # Terminal task manager
    ./rclone.nix # Terminal cloud storage sync
    ./ripgrep.nix # Modern Unix `grep`
    ./senpai.nix # Terminal IRC client
    ./starship.nix # Modern Unix prompt
    ./tldr.nix # Modern Unix `man`
    ./yazi.nix # Modern Unix `mc`
    ./yt-dlp.nix # Terminal YouTube downloader
    ./zoxide.nix # Modern Unix `cd`
  ];
  home = {
    packages =
      with pkgs;
      [
        bc # Terminal calculator
        bmon # Modern Unix `iftop`
        cyme # Modern Unix `lsusb`
        doggo # Modern Unix `dig`
        dua # Modern Unix `du`
        duf # Modern Unix `df`
        dust # Modern Unix `du`
        file # Terminal file info
        frogmouth # Terminal Markdown viewer
        hexyl # Modern Unix `hexedit`
        iperf3 # Terminal network benchmarking
        mtr # Modern Unix `traceroute`
        pciutils # Terminal PCI info
        procs # Modern Unix `ps`
        rsync # Traditional `rsync`
        sd # Modern Unix `sed`
        speedtest-go # Terminal speedtest.net
        unixtools.xxd # Terminal Hexdump
        unzip # Terminal ZIP extractor
        wget # Terminal HTTP client
        xh # Terminal HTTP client
      ]
      ++ lib.optionals host.is.linux [
        lurk # Modern Unix strace
        psmisc # Traditional `ps`
        usbutils # Terminal USB info
      ]
      ++ lib.optionals host.is.workstation [
        bandwhich # Modern Unix `iftop`
        croc # Terminal file transfer
        dotacat # Modern Unix lolcat
        entr # Modern Unix `watch`
        fselect # Modern Unix find with SQL-like syntax
        girouette # Modern Unix weather
        gping # Modern Unix `ping`
        hr # Terminal horizontal rule
        hueadm # Terminal Philips Hue control
        hyperfine # Terminal benchmarking
        jpegoptim # Terminal JPEG optimizer
        lima # Terminal VM manager
        magic-wormhole-rs # Terminal file transfer
        mprocs # Terminal parallel process runner
        netdiscover # Modern Unix `arp`
        optipng # Terminal PNG optimizer
        rustmission # Terminal Transmission Torrent client
        timer # Terminal timer
        upterm # Terminal sharing
        vhs # Terminal GIF recorder; depends on Chromium
      ]
      ++ lib.optionals (host.is.linux && host.is.workstation) [
        batmon # Terminal battery monitor
        figlet # Terminal ASCII banners
        iw # Terminal WiFi info
        s-tui # Terminal CPU stress test
        stress-ng # Terminal CPU stress test
        tty-clock # Terminal clock
        wavemon # Terminal WiFi monitor
        writedisk # Modern Unix `dd`
      ]
      ++ lib.optionals host.is.darwin [
        m-cli # Terminal Swiss Army Knife for macOS
        coreutils
      ];

    # Environment variables for terminal applications
    sessionVariables = lib.mkIf host.is.workstation {
      # Set Catppuccin Mocha theme for Textual-based applications (e.g., frogmouth)
      TEXTUAL_THEME = "catppuccin-mocha";
    };
  };

  programs = {
    bash.shellAliases = shellAliases;
    fish.shellAliases = shellAliases;
    zsh.shellAliases = shellAliases;
  };
}
