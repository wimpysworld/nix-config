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
      basedpyright
      python3
      python313Packages.debugpy
      ruff
      uv
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[python]"."editor.formatOnType" = true;
        };
        extensions = with pkgs; [
          vscode-marketplace.detachhead.basedpyright
          vscode-marketplace.ms-python.debugpy
          vscode-marketplace.ms-python.python
          vscode-marketplace.trond-snekvik.simple-rst
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        "languages" = {
          "Python" = {
            "language_servers" = [
              "${pkgs.basedpyright}/bin/basedpyright"
              "!ty"
            ];
          };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.python
        ]))
      ];
      extraLuaConfig = ''
        -- Python LSP (basedpyright) using Neovim 0.11+ native API
        vim.lsp.enable('basedpyright')
        -- Python formatting with ruff
        require('conform').formatters_by_ft.python = { 'ruff_format' }
      '';
    };
  };
}
