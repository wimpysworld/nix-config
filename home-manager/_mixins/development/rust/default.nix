{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      rust-analyzer
    ];
  };

  claude-code.lspServers.rust = {
    command = lib.getExe pkgs.rust-analyzer;
    extensionToLanguage = {
      ".rs" = "rust";
    };
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "cargotom"
        "tombi"
        "toml"
      ];
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.rust
          p.toml
        ]))
      ];
      extraLuaConfig = ''
        -- Rust LSP (rust-analyzer) using Neovim 0.11+ native API
        vim.lsp.enable('rust_analyzer')
        -- Rust formatting with rustfmt
        require('conform').formatters_by_ft.rust = { 'rustfmt' }
      '';
    };
  };
}
