{ pkgs, ... }:
{
  imports = [
    ./vscode-linux-ext.nix
  ];
  home.packages = with pkgs; [
    black                 # Code format Python
    nodePackages.prettier # Code format
    rustfmt               # Code format Rust
    shellcheck            # Code lint Shell
    shfmt                 # Code format Shell
  ];

  # NOTE! I avoid using home-manager to configure settings.json because it
  #       makes it settings.json immutable. I prefer to use the Code settings
  #       sync extension to sync across machines.
  programs = {
    vscode = {
      enable = true;
      extensions = with pkgs; [
        vscode-extensions.alefragnani.project-manager
        vscode-extensions.bmalehorn.vscode-fish
        vscode-extensions.codezombiech.gitignore
        vscode-extensions.coolbear.systemd-unit-file
        vscode-extensions.dart-code.flutter
        vscode-extensions.dart-code.dart-code
        vscode-extensions.dotjoshjohnson.xml
        vscode-extensions.editorconfig.editorconfig
        vscode-extensions.esbenp.prettier-vscode
        vscode-extensions.github.copilot
        vscode-extensions.github.vscode-github-actions
        vscode-extensions.golang.go
        vscode-extensions.jnoortheen.nix-ide
        vscode-extensions.mads-hartmann.bash-ide-vscode
        vscode-extensions.mechatroner.rainbow-csv
        vscode-extensions.mkhl.direnv
        vscode-extensions.ms-azuretools.vscode-docker
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
        vscode-extensions.vscode-icons-team.vscode-icons
        vscode-extensions.yzhang.markdown-all-in-one
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "bash-debug";
          publisher = "rogalmic";
          version = "0.3.9";
          sha256 = "sha256-f8FUZCvz/PonqQP9RCNbyQLZPnN5Oce0Eezm/hD19Fg=";
        }
        {
          name = "beardedicons";
          publisher = "beardedbear";
          version = "1.15.0";
          sha256 = "sha256-60Mko3e8M+oJ5qYgzXEMi+T6l4Ancc30ViTjJc8jGwk=";
        }
        {
          name = "beardedtheme";
          publisher = "beardedbear";
          version = "8.3.2";
          sha256 = "sha256-TwHuoXme0o6EeciA1lxhs5vmhGlDvaWlH8tjVmuSQH8";
        }
        {
          name = "debian-vscode";
          publisher = "dawidd6";
          version = "0.1.2";
          sha256 = "sha256-DrCaEVf1tnB/ccFTJ5HpJfTxe0npbXMjqGkyHNri+G8=";
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
          name = "simple-rst";
          publisher = "trond-snekvik";
          version = "1.5.4";
          sha256 = "sha256-W3LydBsc7rEHIcjE/0jESFS87uc1DfjuZt6lZhMiQcs=";
        }
        {
          name = "vala";
          publisher = "prince781";
          version = "1.1.0";
          sha256 = "sha256-LJJDKhwzbGznyiXeB8SYir3LOM7/quYhGae1m4X/s3M=";
        }
        {
          name = "vscode-front-matter";
          publisher = "eliostruyf";
          version = "9.3.1";
          sha256 = "sha256-75nnO+JbIXCkEQT8x+F41yn01lRLqsgl+eZ92kJxeZU=";
        }
        {
          name = "vscode-mdx";
          publisher = "unifiedjs";
          version = "1.5.0";
          sha256 = "sha256-UwvicVck4HBbIm+N8pkOGUdr4/j1n0Dg1Iz1nedYAu8=";
        }
        {
          name = "vscode-mdx-preview";
          publisher = "xyc";
          version = "0.3.3";
          sha256 = "sha256-OKwEqkUEjHIJrbi9S2v2nJrZchYByDU6cXHAn7uhxcQ=";
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
}
