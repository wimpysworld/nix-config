{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      bash-language-server
      shellcheck
      shfmt
    ];
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "basher"
        "fish"
      ];
      userSettings = {
        languages = {
          "Shell Script" = {
            format_on_save = "off";
            tab_size = 2;
            hard_tabs = false;
          };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.bash
          p.fish
        ]))
      ];
      extraLuaConfig = ''
        -- Bash LSP using Neovim 0.11+ native API
        vim.lsp.enable('bashls')
        -- Shell formatting with shfmt
        require('conform').formatters_by_ft.sh = { 'shfmt' }
        require('conform').formatters_by_ft.bash = { 'shfmt' }
      '';
    };
  };

  claude-code.lspServers.bash = {
    command = lib.getExe pkgs.bash-language-server;
    args = [ "start" ];
    extensionToLanguage = {
      ".sh" = "shellscript";
      ".bash" = "shellscript";
      ".zsh" = "shellscript";
    };
  };
}
