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
      bash-language-server
      shellcheck
      shfmt
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "shellformat.path" = "${pkgs.shfmt}/bin/shfmt";
          "shellformat.useEditorConfig" = true;
        };
        extensions = with pkgs; [
          vscode-marketplace.bmalehorn.shell-syntax # shell linter
          vscode-marketplace.bmalehorn.vscode-fish # fish linter
          vscode-marketplace.foxundermoon.shell-format # shell formatter
          vscode-marketplace.jeff-hykin.better-shellscript-syntax # shell syntax highlighing
          vscode-marketplace.rogalmic.bash-debug # bash debugger
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "basher"
        "fish"
      ];
      userSettings = {
        languages = {
          "Shell Script" = {
            format_on_save = "on";
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
}
