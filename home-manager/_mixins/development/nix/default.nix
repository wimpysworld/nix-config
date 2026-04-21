{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      deadnix
      nixd
      nix-diff
      nixfmt
      nixfmt-tree
      statix
    ];
  };

  claude-code.lspServers.nix = {
    command = lib.getExe pkgs.nixd;
    extensionToLanguage = {
      ".nix" = "nix";
    };
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        languages = {
          Nix = {
            formatter = {
              external = {
                command = "${pkgs.nixfmt}/bin/nixfmt";
                arguments = [
                  "--quiet"
                  "--"
                ];
              };
            };
            language_servers = [
              "nixd"
            ];
          };
        };
        lsp = {
          nixd = {
            settings = {
              diagnostics = {
                suppress = [ "sema-extra-with" ];
              };
            };
          };
        };
      };
      extensions = [
        "nix"
      ];
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.nix
        ]))
      ];
      extraLuaConfig = ''
        -- Nix LSP (nixd) using Neovim 0.11+ native API
        vim.lsp.config('nixd', {
          settings = {
            nixd = {
              diagnostics = {
                suppress = { 'sema-extra-with' },
              },
            },
          },
        })
        vim.lsp.enable('nixd')
        -- Nix formatting with nixfmt
        require('conform').formatters_by_ft.nix = { 'nixfmt' }
      '';
    };
  };
}
