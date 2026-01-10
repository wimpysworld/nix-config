{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  home = {
    packages = with pkgs; [
      delve
      go
      golangci-lint
      gopls
    ];
    sessionPath = [
      "${config.home.homeDirectory}/.local/go/bin"
    ];
    sessionVariables = {
      GOBIN = "${config.home.homeDirectory}/.local/go/bin";
      GOCACHE = "${config.home.homeDirectory}/.local/go/cache";
      GOPATH = "${config.home.homeDirectory}/.local/go";
    };
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "go.gopath" = "${config.home.homeDirectory}/.local/go";
          "go.survey.prompt" = false;
        };
        extensions = with pkgs; [
          vscode-marketplace.golang.go
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "golangci-lint"
        "gosum"
      ];
      userSettings = {
        languages = {
          Go = {
            formatter = {
              external = {
                command = "golangci-lint";
                arguments = [
                  "run"
                  "--output.json.path"
                  "stdout"
                  "--show-stats=false"
                  "--output.text.path="
                ];
              };
            };
            language_servers = [
              "gopls"
            ];
          };
        };
        lsp = {
          gopls = {
            binary = {
              path_lookup = true;
            };
          };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.go
          p.gomod
          p.gosum
        ]))
      ];
      extraLuaConfig = ''
        -- Go LSP (gopls) using Neovim 0.11+ native API
        vim.lsp.enable('gopls')
        -- Go formatting with gofmt
        require('conform').formatters_by_ft.go = { 'gofmt' }
      '';
    };
  };
}
