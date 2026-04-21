{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      yaml-language-server
      yq-go # Terminal `jq` for YAML
    ];
  };

  programs = {
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

  claude-code.lspServers.yaml = {
    command = lib.getExe pkgs.yaml-language-server;
    args = [ "--stdio" ];
    extensionToLanguage = {
      ".yaml" = "yaml";
      ".yml" = "yaml";
    };
  };
}
