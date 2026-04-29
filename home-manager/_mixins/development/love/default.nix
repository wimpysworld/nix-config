{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf
  (noughtyLib.isHost [
    "skrye"
    "zannah"
  ])
  {
    claude-code.lspServers.lua = {
      command = lib.getExe pkgs.lua-language-server;
      extensionToLanguage = {
        ".lua" = "lua";
      };
    };

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
      zed-editor = lib.mkIf config.programs.zed-editor.enable {
        extensions = [
          "emmylua"
          "glsl"
          "lua"
        ];
        userSettings = {
          languages = {
            Lua = {
              format_on_save = "off";
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
