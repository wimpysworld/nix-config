{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    (vscode-with-extensions.override {
      vscode = unstable.vscode;
      vscodeExtensions = [
        unstable.vscode-extensions.coolbear.systemd-unit-file
        unstable.vscode-extensions.dart-code.flutter
        unstable.vscode-extensions.dart-code.dart-code
        unstable.vscode-extensions.dotjoshjohnson.xml
        unstable.vscode-extensions.eamodio.gitlens
        unstable.vscode-extensions.editorconfig.editorconfig
        unstable.vscode-extensions.esbenp.prettier-vscode
        unstable.vscode-extensions.github.copilot
        unstable.vscode-extensions.github.vscode-github-actions
        unstable.vscode-extensions.golang.go
        unstable.vscode-extensions.jnoortheen.nix-ide
        unstable.vscode-extensions.mads-hartmann.bash-ide-vscode
        unstable.vscode-extensions.mechatroner.rainbow-csv
        unstable.vscode-extensions.ms-azuretools.vscode-docker
        unstable.vscode-extensions.ms-vscode.cpptools
        vscode-extensions.ms-python.python
        vscode-extensions.ms-python.vscode-pylance
        unstable.vscode-extensions.ms-vscode.cmake-tools
        unstable.vscode-extensions.ms-vscode.cpptools
        unstable.vscode-extensions.ms-vsliveshare.vsliveshare
        unstable.vscode-extensions.redhat.vscode-yaml
        unstable.vscode-extensions.ryu1kn.partial-diff
        unstable.vscode-extensions.streetsidesoftware.code-spell-checker
        unstable.vscode-extensions.timonwong.shellcheck
        unstable.vscode-extensions.twxs.cmake
        unstable.vscode-extensions.vscode-icons-team.vscode-icons
        unstable.vscode-extensions.yzhang.markdown-all-in-one
      ] ++ pkgs.unstable.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "bash-debug";
          publisher = "rogalmic";
          version = "0.3.9";
          sha256 = "sha256-f8FUZCvz/PonqQP9RCNbyQLZPnN5Oce0Eezm/hD19Fg=";
        }
        {
          name = "beardedicons";
          publisher = "beardedbear";
          version = "1.13.2";
          sha256 = "sha256-PpIut/yhUNK1eTPRvVXONt06TOXpoGgmd6lrhFdADRQ";
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
          version = "0.23.15";
          sha256 = "sha256-/LjLL8IQwQ0ghh5YoDWQxcPM33FCjPeg3cFb1Qa/cb0=";
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
          name = "simple-rst";
          publisher = "trond-snekvik";
          version = "1.5.3";
          sha256 = "sha256-0gPqckwzDptpzzg1tP4I9WQfrXlflO+G0KcAK5pEie8=";
        }
        {
          name = "vala";
          publisher = "prince781";
          version = "1.0.8";
          sha256 = "sha256-IuIb7vLNiE3rzVHOsjInaYLzNYORbwabQq0bfaPLlqc=";
        }
        {
          name = "vscode-front-matter";
          publisher = "eliostruyf";
          version = "8.4.0";
          sha256 = "sha256-L0PbZ4HxJAlxkwVcZe+kBGS87yzg0pZl89PU0aUVYzY=";
        }
        {
          name = "vscode-mdx";
          publisher = "unifiedjs";
          version = "1.4.0";
          sha256 = "sha256-qqqq0QKTR0ZCLdPltsnQh5eTqGOh9fV1OSOZMjj4xXg=";
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
    })
  ];

  services.vscode-server.enable = true;
  # May require the service to be enable/started for the user
  # - systemctl --user enable auto-fix-vscode-server.service --now
}
