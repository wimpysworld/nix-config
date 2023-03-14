{ inputs, nixpkgs, outputs, pkgs, ... }: {
  imports = [
    ./fish.nix
    ./git.nix
    ./htop.nix
    ./neofetch.nix
    ./xdg.nix
  ];

  home = {
    # A Modern Unix experience
    packages = with pkgs; [
      alejandra       # Nix code formatter
      asciinema       # Terminal recorder
      bottom          # Modern Unix `top`
      btop            # Modern Unix `top`
      curlie          # Terminal HTTP client
      dconf2nix       # Nix code from Dconf files
      deadnix         # Nix dead code scanner
      diffr           # Modern Unix `diff`
      dogdns          # Modern Unix `dig`
      duf             # Modern Unix `du`
      fd              # Modern Unix `find`
      glow            # Terminal Markdown renderer
      gping           # Modern Unix `ping`
      gtop            # Modern Unix `top`
      hexyl           # Modern Unix `hexedit`
      httpie          # Terminal HTTP client
      hyperfine       # Terminal benchmarking
      maestral        # Terminal Dropbox client
      most            # Modern Unix `less`
      nix-direnv      # Nix direnv
      nixpkgs-fmt     # Nix code formmater
      nyancat         # Terminal rainbow spewing feline
      procs           # Modern Unix `ps`
      ripgrep         # Modern Unix `grep`
      speedtest-rs    # Terminal speedtest
      tldr            # Modern Unix `man`
      tokei           # Modern Unix `wc` for code
      yadm            # Terminal dot file manager
      zenith          # Modern Unix `top`
    ];
    sessionVariables = {
      EDITOR = "nano";
      PAGER = "most";
      SYSTEMD_EDITOR = "nano";
      VISUAL = "nano";
    };
  };

  programs = {
    atuin.enableFishIntegration = true;
    bat.enable = true;
    exa = {
      enable = true;
      enableAliases = true;
      icons = true;
    };
    gpg.enable = true;
    home-manager.enable = true;
    jq.enable = true;
    powerline-go.enable = true;
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
}
