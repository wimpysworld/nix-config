{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation) {
  home = {
    packages = with pkgs; [
      yaml-language-server
      yq-go # Terminal `jq` for YAML
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[yaml]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "redhat.telemetry.enabled" = false;
          "yaml.keyOrdering" = true;
        };
        extensions = with pkgs; [
          vscode-marketplace.redhat.vscode-yaml
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        languages = {
          YAML = {
            formatter = {
              external = {
                command = "prettier";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
            };
          };
        };
        lsp = {
          yaml-language-server = {
            settings = {
              yaml = {
                # Enforces alphabetical ordering of keys in maps
                keyOrdering = true;
              };
            };
          };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.yaml
        ]))
      ];
      extraLuaConfig = ''
        -- YAML LSP using Neovim 0.11+ native API
        vim.lsp.config('yamlls', {
          settings = {
            yaml = {
              keyOrdering = true,
            },
          },
        })
        vim.lsp.enable('yamlls')
        -- YAML formatting with prettier
        require('conform').formatters_by_ft.yaml = { 'prettier' }
      '';
    };
  };
}
