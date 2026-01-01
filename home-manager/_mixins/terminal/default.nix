{
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  shellAliases = {
    banner = "${pkgs.figlet}/bin/figlet";
    banner-color = "${pkgs.figlet}/bin/figlet $argv | ${pkgs.dotacat}/bin/dotacat";
    clock = if (isLinux) then ''${pkgs.tty-clock}/bin/tty-clock -B -c -C 4 -f "%a, %d %b"'' else "date";
    dadjoke = ''${pkgs.curlMinimal}/bin/curl --header "Accept: text/plain" https://icanhazdadjoke.com/'';
    dmesg = "${pkgs.util-linux}/bin/dmesg --human --color=always";
    egrep = "${pkgs.gnugrep}/bin/egrep --color=auto";
    fgrep = "${pkgs.gnugrep}/bin/fgrep --color=auto";
    glow = "${pkgs.frogmouth}/bin/frogmouth";
    grep = "${pkgs.gnugrep}/bin/grep --color=auto";
    hr = ''${pkgs.hr}/bin/hr "─━"'';
    ip = if (isLinux) then "${pkgs.iproute2}/bin/ip --color --brief" else "ipconfig getifaddr en0";
    lolcat = "${pkgs.dotacat}/bin/dotacat";
    lsusb = "${pkgs.cyme}/bin/cyme --headings";
    moon = "${pkgs.curlMinimal}/bin/curl -s wttr.in/Moon";
    rsync-copy = "${pkgs.rsync}/bin/rsync --archive --block-size=131072 --human-readable --info=progress2 --inplace --no-compress --partial --stats";
    rsync-mirror = "${pkgs.rsync}/bin/rsync --archive --block-size=131072 --delete --human-readable --info=progress2 --no-compress --inplace --partial --stats";
    ruler = ''${pkgs.hr}/bin/hr "╭─³⁴⁵⁶⁷⁸─╮"'';
    speedtest = "${pkgs.speedtest-go}/bin/speedtest-go";
    wormhole = "${pkgs.wormhole-rs}/bin/wormhole-rs";
    weather = "${lib.getExe pkgs.girouette} --quiet";
    lock-armstrong = "fusermount -u ~/Vaults/Armstrong";
    unlock-armstrong = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Armstrong ~/Vaults/Armstrong";
    lock-secrets = "fusermount -u ~/Vaults/Secrets";
    unlock-secrets = "${pkgs.gocryptfs}/bin/gocryptfs ~/Crypt/Secrets ~/Vaults/Secrets";
  };
in
{
  imports = [
    ./atuin.nix # Modern Unix shell history
    ./bat.nix # Modern Unix `cat`
    ./bottom.nix # Modern Unix `top`
    ./btop.nix # Modern Unix `htop`
    ./cava.nix # Terminal audio visualizer
    ./dircolors.nix # Terminal colors
    ./direnv.nix # Modern Unix `env`
    ./eza.nix # Modern Unix `ls`
    ./fastfetch.nix # Modern Unix `neofetch`
    ./fd.nix # Modern Unix `find`
    ./fzf.nix # Terminal fuzzy finder
    ./gh.nix # Terminal GitHub client`
    ./git.nix # Terminal Git client
    ./gpg.nix # Terminal GPG
    ./jq.nix # Terminal JSON processor
    ./micro.nix # Terminal text editor
    ./pueue.nix # Terminal task manager
    ./rclone.nix # Terminal cloud storage sync
    ./ripgrep.nix # Modern Unix `grep`
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
        bandwhich # Modern Unix `iftop`
        bmon # Modern Unix `iftop`
        croc # Terminal file transfer
        cyme # Modern Unix `lsusb`
        dconf2nix # Nix code from Dconf files
        dogdns # Modern Unix `dig`
        dotacat # Modern Unix lolcat
        dua # Modern Unix `du`
        duf # Modern Unix `df`
        dust # Modern Unix `du`
        entr # Modern Unix `watch`
        file # Terminal file info
        frogmouth # Terminal markdown viewer
        fselect # Modern Unix find with SQL-like syntax
        girouette # Modern Unix weather
        gocryptfs # Terminal encrypted filesystem
        gping # Modern Unix `ping`
        hexyl # Modern Unix `hexedit`
        hr # Terminal horizontal rule
        hueadm # Terminal Philips Hue control
        hyperfine # Terminal benchmarking
        iperf3 # Terminal network benchmarking
        jpegoptim # Terminal JPEG optimizer
        lima # Terminal VM manager
        magic-wormhole-rs # Terminal file transfer
        marp-cli # Terminal Markdown presenter
        mprocs # Terminal parallel process runner
        mtr # Modern Unix `traceroute`
        netdiscover # Modern Unix `arp`
        optipng # Terminal PNG optimizer
        pciutils # Terminal PCI info
        presenterm # Terminal Markdown presenter
        procs # Modern Unix `ps`
        rsync # Traditional `rsync`
        rustmission # Terminal Transmission Torrent client
        sd # Modern Unix `sed`
        speedtest-go # Terminal speedtest.net
        timer # Terminal timer
        unzip # Terminal ZIP extractor
        upterm # Terminal sharing
        wget # Terminal HTTP client
        wget2 # Terminal HTTP client
        xh # Terminal HTTP client
        yq-go # Terminal `jq` for YAML
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        batmon # Terminal battery monitor
        figlet # Terminal ASCII banners
        iw # Terminal WiFi info
        lurk # Modern Unix strace
        psmisc # Traditional `ps`
        s-tui # Terminal CPU stress test
        stress-ng # Terminal CPU stress test
        tty-clock # Terminal clock
        usbutils # Terminal USB info
        vhs # Terminal GIF recorder
        wavemon # Terminal WiFi monitor
        writedisk # Modern Unix `dd`
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
        m-cli # Terminal Swiss Army Knife for macOS
        coreutils
      ];
  };

  programs = {
    bash.shellAliases = shellAliases;
    fish.shellAliases = shellAliases;
    zsh.shellAliases = shellAliases;
  };
}
