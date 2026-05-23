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
  claude-code.lspServers.cpp = {
    command = "${pkgs.clang-tools}/bin/clangd";
    extensionToLanguage = {
      ".c" = "c";
      ".h" = "c";
      ".cpp" = "cpp";
      ".hpp" = "cpp";
      ".cc" = "cpp";
      ".cxx" = "cpp";
    };
  };

  fresh.settings.lsp = {
    c = {
      command = "${pkgs.clang-tools}/bin/clangd";
      enabled = true;
      auto_start = true;
    };
    cpp = {
      command = "${pkgs.clang-tools}/bin/clangd";
      enabled = true;
      auto_start = true;
    };
  };

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
  };
}
