{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  home = {
    packages = with pkgs; [
      bear # Generate compile_commands.json for non-CMake projects
      clang-tools # clangd (LSP), clang-format, clang-tidy
      cmake
      gnumake
      lldb # Debugger
      neocmakelsp # CMake LSP
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions =
          with pkgs;
          [
            vscode-marketplace.ms-vscode.cmake-tools
            vscode-marketplace.twxs.cmake
          ]
          ++ lib.optionals host.is.linux [
            vscode-extensions.ms-vscode.cpptools-extension-pack
            vscode-extensions.vadimcn.vscode-lldb
          ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "neocmake"
      ];
      userSettings = {
        languages = {
          C = {
            format_on_save = "off";
            tab_size = 2;
          };
          "C++" = {
            format_on_save = "off";
            tab_size = 2;
          };
          CMake = {
            format_on_save = "off";
            tab_size = 2;
            language_servers = [
              "neocmakelsp"
            ];
          };
        };
        lsp = {
          clangd = { };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.c
          p.cmake
          p.cpp
          p.make
        ]))
      ];
      extraLuaConfig = ''
        -- C/C++ LSP (clangd) using Neovim 0.11+ native API
        vim.lsp.enable('clangd')
        -- CMake LSP (neocmakelsp)
        vim.lsp.enable('neocmakelsp')
        -- C/C++ formatting with clang-format
        require('conform').formatters_by_ft.c = { 'clang-format' }
        require('conform').formatters_by_ft.cpp = { 'clang-format' }
      '';
    };
  };
}
