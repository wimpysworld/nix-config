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
      # Node.js runtime and package manager
      nodejs_24

      # JavaScript/TypeScript tooling
      unstable.bun
      tsx
      typescript
      typescript-language-server
      vscode-js-debug
      vtsls

      # Language servers for web technologies
      vscode-langservers-extracted # JSON, HTML, CSS, ESLint
    ];
  };

  programs = {
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.css
          p.html
          p.javascript
          p.json
          p.tsx
          p.typescript
        ]))
      ];
      extraLuaConfig = ''
        -- JavaScript/TypeScript LSP (ts_ls) using Neovim 0.11+ native API
        vim.lsp.enable('ts_ls')
        -- JSON/CSS/HTML LSPs using Neovim 0.11+ native API
        vim.lsp.enable({'jsonls', 'cssls', 'html'})
      '';
    };
  };
}
