{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.workstation {
  home = {
    packages = with pkgs; [
      svelte-check
      svelte-language-server
    ];
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "svelte"
      ];
      userSettings = {
        languages = {
          Svelte = {
            formatter = {
              external = {
                command = "prettier";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
            };
          };
        };
      };
    };
  };

  claude-code.lspServers.svelte = {
    command = lib.getExe pkgs.svelte-language-server;
    args = [ "--stdio" ];
    extensionToLanguage = {
      ".svelte" = "svelte";
    };
  };

  programs.fresh-editor.settings.lsp.svelte = {
    command = lib.getExe pkgs.svelte-language-server;
    args = [ "--stdio" ];
    enabled = true;
    auto_start = true;
  };
}
