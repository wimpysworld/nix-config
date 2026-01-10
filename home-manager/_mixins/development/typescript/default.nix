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
      unstable.bun
      tsx
      typescript
      typescript-language-server
      vscode-js-debug
      vtsls
    ];
  };

  programs = {
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.javascript
          p.tsx
          p.typescript
        ]))
      ];
      extraLuaConfig = ''
        -- TypeScript/JavaScript LSP (ts_ls) using Neovim 0.11+ native API
        vim.lsp.enable('ts_ls')
      '';
    };
  };
}
