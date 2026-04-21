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

  claude-code.lspServers.svelte = {
    command = lib.getExe pkgs.svelte-language-server;
    args = [ "--stdio" ];
    extensionToLanguage = {
      ".svelte" = "svelte";
    };
  };
}
