{ config, lib, hostname, pkgs, username, ... }: {
  imports = [
    ../../services/keybase.nix
    ../../services/syncthing.nix
  ];
  home = {
    file.".bazaar/authentication.conf".text = "
      [Launchpad]
      host = .launchpad.net
      scheme = ssh
      user = flexiondotorg
    ";
    file.".bazaar/bazaar.conf".text = "
      [DEFAULT]
      email = Martin Wimpress <code@wimpress.io>
      launchpad_username = flexiondotorg
      mail_client = default
      tab_width = 4
      [ALIASES]
    ";
    file.".distroboxrc".text = "
      xhost +si:localuser:$USER
    ";
    file.".face".source = ./face.png;
    #file."Development/debian/.envrc".text = "export DEB_VENDOR=Debian";
    #file."Development/ubuntu/.envrc".text = "export DEB_VENDOR=Ubuntu";
    file.".ssh/config".text = "
      Host github.com
        HostName github.com
        User git

      Host man
        HostName man.wimpress.io

      Host yor
        HostName yor.wimpress.io

      Host man.ubuntu-mate.net
        HostName man.ubuntu-mate.net
        User matey
        IdentityFile ~/.ssh/id_rsa_semaphore

      Host yor.ubuntu-mate.net
        HostName yor.ubuntu-mate.net
        User matey
        IdentityFile ~/.ssh/id_rsa_semaphore

      Host bazaar.launchpad.net
        User flexiondotorg

      Host git.launchpad.net
        User flexiondotorg

      Host ubuntu.com
        HostName people.ubuntu.com
        User flexiondotorg

      Host people.ubuntu.com
        User flexiondotorg

      Host ubuntupodcast.org
        HostName live.ubuntupodcast.org
    ";
    file."Quickemu/nixos-console.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-console/disk.qcow2"
      disk_size="96G"
      iso="nixos-console/nixos.iso"
    '';
    file."Quickemu/nixos-desktop.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-desktop/disk.qcow2"
      disk_size="96G"
      iso="nixos-desktop/nixos.iso"
    '';
    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages = with pkgs; [
      asciinema # Terminal recorder
      black # Code format Python
      bmon # Modern Unix `iftop`
      breezy # Terminal bzr client
      butler # Terminal Itch.io API client
      chafa # Terminal image viewer
      chroma # Code syntax highlighter
      clinfo # Terminal OpenCL info
      curlie # Terminal HTTP client
      dconf2nix # Nix code from Dconf files
      debootstrap # Terminal Debian installer
      diffr # Modern Unix `diff`
      difftastic # Modern Unix `diff`
      dogdns # Modern Unix `dig`
      dua # Modern Unix `du`
      duf # Modern Unix `df`
      du-dust # Modern Unix `du`
      entr # Modern Unix `watch`
      fast-cli # Terminal fast.com
      fd # Modern Unix `find`
      glow # Terminal Markdown renderer
      gping # Modern Unix `ping`
      hexyl # Modern Unix `hexedit`
      httpie # Terminal HTTP client
      hyperfine # Terminal benchmarking
      iperf3 # Terminal network benchmarking
      iw # Terminal WiFi info
      jpegoptim # Terminal JPEG optimizer
      jiq # Modern Unix `jq`
      lazygit # Terminal Git client
      libva-utils # Terminal VAAPI info
      lurk # Modern Unix `strace`
      mdp # Terminal Markdown presenter
      moar # Modern Unix `less`
      mtr # Modern Unix `traceroute`
      netdiscover # Modern Unix `arp`
      nethogs # Modern Unix `iftop`
      nixpkgs-review # Nix code review
      nodePackages.prettier # Code format
      nurl # Nix URL fetcher
      nyancat # Terminal rainbow spewing feline
      speedtest-go # Terminal speedtest.net 
      optipng # Terminal PNG optimizer
      procs # Modern Unix `ps`
      python310Packages.gpustat # Terminal GPU info
      quilt # Terminal patch manager
      ripgrep # Modern Unix `grep`
      rustfmt # Code format Rust
      shellcheck # Code lint Shell
      shfmt # Code format Shell
      tldr # Modern Unix `man`
      tokei # Modern Unix `wc` for code
      vdpauinfo # Terminal VDPAU info
      wavemon # Terminal WiFi monitor
      yq-go # Terminal `jq` for YAML
    ];
    sessionVariables = {
      BZR_EMAIL = "Martin Wimpress <code@wimpress.io>";
      DEBFULLNAME = "Martin Wimpress";
      DEBEMAIL = "code@wimpress.io";
      DEBSIGN_KEYID = "8F04688C17006782143279DA61DF940515E06DA3";
      PAGER = "moar";
    };
  };
  programs = {
    fish = {
      shellAliases = {
        diff = "diffr";
        fast = "fast -u";
        glow = "glow --pager";
        moon = "curl -s wttr.in/Moon";
        pubip = "curl -s ifconfig.me/ip";
        #pubip = "curl -s https://api.ipify.org";
        speedtest = "speedtest-go";
        wttr = "curl -s wttr.in && curl -s v2.wttr.in";
        wttr-bas = "curl -s wttr.in/basingstoke && curl -s v2.wttr.in/basingstoke";
      };
    };
    git = {
      userEmail = "martin@wimpress.org";
      userName = "Martin Wimpress";
      signing = {
        key = "15E06DA3";
        signByDefault = true;
      };
    };
  };

  systemd.user.tmpfiles.rules = [
    "d ${config.home.homeDirectory}/Development/debian 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/DeterminateSystems 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/flexiondotorg 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/mate-desktop 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/NixOS 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/quickemu-project 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/restfulmedia 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/ubuntu 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/ubuntu-mate 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Development/wimpysworld 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Dropbox 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Games 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Quickemu/nixos-console 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Quickemu/nixos-desktop 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Scripts 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/ 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Syncthing 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Volatile/Vorta 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Websites 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Zero 0755 ${username} users - -"
    "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
  ];
}
