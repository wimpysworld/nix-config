{ config, desktop, inputs, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  # import the DE specific configuration and any user specific desktop configuration
  imports = [
    ./apps/discord
  ] ++ lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop}
    ++ lib.optional (builtins.pathExists (./. + "/../users/${username}/desktop.nix")) ../users/${username}/desktop.nix;

  nixpkgs.overlays = [ inputs.catppuccin-vsc.overlays.default ];

  home = {
    # Authrorize X11 access in Distrobox
    file.".distroboxrc" = lib.mkIf isLinux {
      text = ''
        ${pkgs.xorg.xhost}/bin/xhost +si:localuser:$USER
      '';
    };
    packages = with pkgs; [
      # cross-platform desktop apps
      chatterino2
      gitkraken
      # cross platform dev tools
      black                 # Code format Python
      nodePackages.prettier # Code format
      rustfmt               # Code format Rust
      shellcheck            # Code lint Shell
      shfmt                 # Code format Shell
    ] ++ lib.optionals (isDarwin) [
      # macOS apps
      iterm2
      pika
      utm
    ];
  };

  # NOTE! I avoid using home-manager to configure settings.json because it
  #       makes it settings.json immutable. I prefer to use the Code settings
  #       sync extension to sync across machines.
  programs = {
    vscode = {
      enable = true;
      extensions = with pkgs; [
            # all the theme options will be available as overrides, these are defaults:
            (catppuccin-vsc.override {
              accent = "blue";
              boldKeywords = true;
              italicComments = true;
              italicKeywords = true;
              extraBordersEnabled = false;
              workbenchMode = "default";
              bracketMode = "rainbow";
              colorOverrides = {};
              customUIColors = {};
            })
        vscode-extensions.alefragnani.project-manager
        vscode-extensions.codezombiech.gitignore
        vscode-extensions.coolbear.systemd-unit-file
        vscode-extensions.dart-code.flutter
        vscode-extensions.dart-code.dart-code
        vscode-extensions.dotjoshjohnson.xml
        vscode-extensions.editorconfig.editorconfig
        vscode-extensions.esbenp.prettier-vscode
        vscode-extensions.github.copilot
        vscode-extensions.github.copilot-chat
        vscode-extensions.github.vscode-github-actions
        vscode-extensions.golang.go
        vscode-extensions.jnoortheen.nix-ide
        vscode-extensions.mads-hartmann.bash-ide-vscode
        vscode-extensions.mkhl.direnv
        vscode-extensions.ms-python.python
        vscode-extensions.ms-python.vscode-pylance
        vscode-extensions.ms-vscode.cmake-tools
        vscode-extensions.ms-vscode.hexeditor
        vscode-extensions.redhat.vscode-yaml
        vscode-extensions.rust-lang.rust-analyzer
        vscode-extensions.ryu1kn.partial-diff
        vscode-extensions.serayuzgur.crates
        vscode-extensions.streetsidesoftware.code-spell-checker
        vscode-extensions.tamasfe.even-better-toml
        vscode-extensions.timonwong.shellcheck
        vscode-extensions.twxs.cmake
        vscode-extensions.yzhang.markdown-all-in-one
      ] ++ lib.optionals (isLinux) [
        vscode-extensions.ms-vscode.cpptools
        vscode-extensions.ms-vsliveshare.vsliveshare
        vscode-extensions.vadimcn.vscode-lldb
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "bash-debug";
          publisher = "rogalmic";
          version = "0.3.9";
          sha256 = "sha256-f8FUZCvz/PonqQP9RCNbyQLZPnN5Oce0Eezm/hD19Fg=";
        }
        {
          name = "better-comments";
          publisher = "aaron-bond";
          version = "3.0.2";
          sha256 = "sha256-hQmA8PWjf2Nd60v5EAuqqD8LIEu7slrNs8luc3ePgZc=";
        }
        {
          name = "better-csv-syntax";
          publisher = "jeff-hykin";
          version = "0.0.2";
          sha256 = "sha256-lNOESQgMwtjM7eTD8KQLWATktF2wjZzdpTng45i05LI=";
        }
        {
          name = "better-dockerfile-syntax";
          publisher = "jeff-hykin";
          version = "1.0.2";
          sha256 = "sha256-FaF+rhtAoWslmBoxet8rINyQlMxNl8kX1EE89ymnCcQ=";
        }
        {
          name = "better-nix-syntax";
          publisher = "jeff-hykin";
          version = "1.1.5";
          sha256 = "sha256-9V+ziWk9V4LyQiVNSC6DniJDun+EvcK30ykPjyNsvp0=";
        }
        {
          name = "better-shellscript-syntax";
          publisher = "jeff-hykin";
          version = "1.8.7";
          sha256 = "sha256-SSRoQSowBmebplX2dWIP50ErroNfe0Wgtuz7y77LB8Y=";
        }
        {
          name = "catppuccin-vsc-icons";
          publisher = "Catppuccin";
          version = "1.13.0";
          sha256 = "sha256-4gsblUMcN7a7UgoklBjc+2uiaSERq1vmi0exLht+Xi0=";
        }
        {
          name = "debian-control-vscode";
          publisher = "jdemille";
          version = "0.2.0";
          sha256 = "sha256-5XRtEKCZ/cOq9HiN4AwaZqcgAPSz3pruG1jVUyPuNz8=";
        }
        {
          name = "font-switcher";
          publisher = "evan-buss";
          version = "4.1.0";
          sha256 = "sha256-KkXUfA/W73kRfs1TpguXtZvBXFiSMXXzU9AYZGwpVsY=";
        }
        {
          name = "grammarly";
          publisher = "znck";
          version = "0.25.0";
          sha256 = "sha256-/wiUkAivEPYpPFF4X+d9PCrRHPRTlhW+NnEoqBxUCxE=";
        }
        {
          name = "language-hugo-vscode";
          publisher = "budparr";
          version = "1.3.1";
          sha256 = "sha256-9dp8/gLAb8OJnmsLVbOAKAYZ5whavPW2Ak+WhLqEbJk=";
        }
        {
          name = "linux-desktop-file";
          publisher = "nico-castell";
          version = "0.0.21";
          sha256 = "sha256-4qy+2Tg9g0/9D+MNvLSgWUE8sc5itsC/pJ9hcfxyVzQ=";
        }
        {
          name = "material-product-icons";
          publisher = "PKief";
          version = "1.7.0";
          sha256 = "sha256-F6sukBQ61pHoKTxx88aa8QMLDOm9ozPF9nonIH34C7Q=";
        }
        {
          name = "nelua";
          publisher = "alexgb";
          version = "0.1.0";
          sha256 = "sha256-6r0l6p6rDBeCTPLqFRHD3/hQJxb8me08C0Zqti8Hr18=";
        }
        {
          name = "non-breaking-space-highlighter";
          publisher = "viktorzetterstrom";
          version = "0.0.3";
          sha256 = "sha256-t+iRBVN/Cw/eeakRzATCsV8noC2Wb6rnbZj7tcZJ/ew=";
        }
        {
          name = "openwithkraken";
          publisher = "s3anmorrow";
          version = "1.0.0";
          sha256 = "sha256-zsJjHKHycgT305TVq0SdhZp7zY9ejhSF2SCOPktloGc=";
        }
        {
          name = "polacode-2019";
          publisher = "jeff-hykin";
          version = "0.6.1";
          sha256 = "sha256-SbfsD28gaVHAmJskUuc1Q8kA47jrVa3OO5Ur7ULk3jI=";
        }
        {
          name = "pubspec-assist";
          publisher = "jeroen-meijer";
          version = "2.3.2";
          sha256 = "sha256-+Mkcbeq7b+vkuf2/LYT10mj46sULixLNKGpCEk1Eu/0=";
        }
        {
          name = "shell-format";
          publisher = "foxundermoon";
          version = "7.2.5";
          sha256 = "sha256-kfpRByJDcGY3W9+ELBzDOUMl06D/vyPlN//wPgQhByk=";
        }
        {
          name = "shell-syntax";
          publisher = "bmalehorn";
          version = "1.0.5";
          sha256 = "sha256-83WWzHP6R18r8xX3vrLpqj1uScYeE5N1Z4up3o2EB8c=";
        }
        {
          name = "simple-rst";
          publisher = "trond-snekvik";
          version = "1.5.4";
          sha256 = "sha256-W3LydBsc7rEHIcjE/0jESFS87uc1DfjuZt6lZhMiQcs=";
        }
        {
          name = "unfoldai";
          publisher = "TalDennis-UnfoldAI-ChatGPT-Copilot";
          version = "0.4.3";
          sha256 = "sha256-57cfT5T0LBLlp/ugYWYGUsx42rEoFSilXokWqzxkFhE=";
        }
        {
          name = "vala";
          publisher = "prince781";
          version = "1.1.0";
          sha256 = "sha256-LJJDKhwzbGznyiXeB8SYir3LOM7/quYhGae1m4X/s3M=";
        }
        {
          name = "vscode-fish";
          publisher = "bmalehorn";
          version = "1.0.38";
          sha256 = "sha256-QEifCTlzYMX+5H6+k2o1lsQrhW3vxVpn+KFg/3WVVFo=";
        }
        {
          name = "vscode-front-matter";
          publisher = "eliostruyf";
          version = "10.1.0";
          sha256 = "sha256-TQ3jcXOcSQMoYGihKg6oSSPTtQtXIEzTbYRVyA0SyLE=";
        }
        {
          name = "vscode-mdx";
          publisher = "unifiedjs";
          version = "1.8.4";
          sha256 = "sha256-QKI7GaASrWzdjC/gb0JNDAlTtAdQOGo/c1RE5WrmIZ0=";
        }
        {
          name = "vscode-mdx-preview";
          publisher = "xyc";
          version = "0.3.3";
          sha256 = "sha256-OKwEqkUEjHIJrbi9S2v2nJrZchYByDU6cXHAn7uhxcQ=";
        }
        {
          name = "vscode-pets";
          publisher = "tonybaloney";
          version = "1.25.1";
          sha256 = "sha256-as3e2LzKBSsiGs/UGIZ06XqbLh37irDUaCzslqITEJQ=";
        }
        {
          name = "vscode-power-mode";
          publisher = "hoovercj";
          version = "3.0.2";
          sha256 = "sha256-ZE+Dlq0mwyzr4nWL9v+JG00Gllj2dYwL2r9jUPQ8umQ=";
        }
      ];
      mutableExtensionsDir = true;
      package = pkgs.vscode;
    };
  };

  xresources.properties = {
    "*background" = "#1E1E2E";
    "*foreground" = "#CDD6F4";
    # black
    "*color0" = "#45475A";
    "*color8" = "#585B70";
    # red
    "*color1" = "#F38BA8";
    "*color9" = "#F38BA8";
    # green
    "*color2" = "#A6E3A1";
    "*color10" = "#A6E3A1";
    # yellow
    "*color3" = "#F9E2AF";
    "*color11" = "#F9E2AF";
    # blue
    "*color4" = "#89B4FA";
    "*color12" = "#89B4FA";
    #magenta
    "*color5" = "#F5C2E7";
    "*color13" = "#F5C2E7";
    #cyan
    "*color6" = "#94E2D5";
    "*color14" = "#94E2D5";
    #white
    "*color7" = "#BAC2DE";
    "*color15" = "#A6ADC8";

    # Xterm Appearance
    "XTerm*background" = "#1E1E2E";
    "XTerm*foreground" = "#CDD6F4";
    "XTerm*letterSpace" = 0;
    "XTerm*lineSpace" = 0;
    "XTerm*geometry" = "132x50";
    "XTerm.termName" = "xterm-256color";
    "XTerm*internalBorder" = 2;
    "XTerm*faceName" = "FiraCode Nerd Font Mono:size=14:style=Medium:antialias=true";
    "XTerm*boldFont" = "FiraCode Nerd Font Mono:size=14:style=Bold:antialias=true";
    "XTerm*boldColors" = true;
    "XTerm*cursorBlink" = true;
    "XTerm*cursorUnderline" = false;
    "XTerm*saveline" = 2048;
    "XTerm*scrollBar" = false;
    "XTerm*scrollBar_right" = false;
    "XTerm*urgentOnBell" = true;
    "XTerm*depth" = 24;
    "XTerm*utf8" = true;
    "XTerm*locale" = false;
    "XTerm.vt100.metaSendsEscape" = true;
  };
}
