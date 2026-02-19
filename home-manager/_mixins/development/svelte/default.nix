{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      svelte-check
      svelte-language-server
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[svelte]"."editor.defaultFormatter" = "svelte.svelte-vscode";
          "svelte.enable-ts-plugin" = true;
          "svelte.language-server.ls-path" = "${pkgs.svelte-language-server}/bin/svelte-language-server";
        };
        extensions = with pkgs; [
          vscode-marketplace.svelte.svelte-vscode
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "svelte"
      ];
      userSettings = {
        languages = {
          Svelte = {
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
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.svelte
        ]))
      ];
      extraLuaConfig = ''
        -- Svelte LSP using Neovim 0.11+ native API
        vim.lsp.enable('svelte')
        -- Svelte formatting with prettier
        require('conform').formatters_by_ft.svelte = { 'prettier' }
      '';
    };
  };
}
