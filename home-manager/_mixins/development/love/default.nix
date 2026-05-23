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

    fresh.settings.lsp.lua = {
      command = lib.getExe pkgs.lua-language-server;
      enabled = true;
      auto_start = true;
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
    };
  }
