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
      deadnix
      nixd
      nix-diff
      nixfmt
      nixfmt-tree
      statix
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
          "[nix]"."editor.formatOnSave" = true;
          "[nix]"."editor.tabSize" = 2;
          "nix.enableLanguageServer" = true;
          "nix.formatterPath" = "nixfmt";
          "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
          "nix.serverSettings" = {
            "nixd" = {
              "formatting" = {
                "command" = [ "${pkgs.nixfmt}/bin/nixfmt" ];
              };
            };
          };
        };
        extensions = with pkgs; [
          vscode-marketplace.jeff-hykin.better-nix-syntax
          vscode-marketplace.jnoortheen.nix-ide
        ];
      };
    };
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
