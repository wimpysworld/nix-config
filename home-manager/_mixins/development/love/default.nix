{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  home = {
    packages = with pkgs; [
      glslang
      love
      luaformatter
      luajit
      lua-language-server
      stylua
      tree-sitter-grammars.tree-sitter-lua
    ];
  };
  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[lua]"."editor.defaultFormatter" = "JohnnyMorganz.stylua";
        };
        extensions = with pkgs; [
          vscode-marketplace.dtoplak.vscode-glsllint
          vscode-marketplace.ismoh-games.second-local-lua-debugger-vscode
          vscode-marketplace.johnnymorganz.stylua
          vscode-marketplace.pixelbyte-studios.pixelbyte-love2d
          vscode-marketplace.slevesque.shader
          vscode-marketplace.sumneko.lua
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "emmylua"
        "glsl"
        "lua"
      ];
      userSettings = {
        languages = {
          Lua = {
            format_on_save = "on";
            formatter = {
              external = {
                command = "stylua";
                arguments = [
                  "--syntax=Lua54"
                  "--respect-ignores"
                  "--stdin-filepath"
                  "{buffer_path}"
                  "-"
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
          p.lua
        ]))
      ];
      extraLuaConfig = ''
        -- Lua LSP using Neovim 0.11+ native API
        vim.lsp.config('lua_ls', {
          settings = {
            Lua = {
              runtime = { version = 'LuaJIT' },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        })
        vim.lsp.enable('lua_ls')
        -- Lua formatting with stylua
        require('conform').formatters_by_ft.lua = { 'stylua' }
      '';
    };
  };
}
