{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      delve
      go
      go-licenses
      golangci-lint
      golangci-lint-langserver
      gopls
      goreleaser
      gotools
      govulncheck
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

  claude-code.lspServers.go = {
    command = lib.getExe pkgs.gopls;
    extensionToLanguage = {
      ".go" = "go";
    };
  };

  claude-code.lspServers.golangci-lint-langserver = {
    command = lib.getExe pkgs.golangci-lint-langserver;
    extensionToLanguage = {
      ".go" = "go";
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
                command = "gofmt";
                arguments = [ ];
              };
            };
            language_servers = [
              "gopls"
              "golangci-lint-langserver"
            ];
          };
        };
        lsp = {
          gopls = { };
          golangci-lint-langserver = { };
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
        vim.lsp.enable('golangci-lint-langserver')
        -- Go formatting with gofmt
        require('conform').formatters_by_ft.go = { 'gofmt' }
      '';
    };
  };
}
