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
      svelte-check
      svelte-language-server
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[svelte]"."editor.defaultFormatter" = "svelte.svelte-vscode";
          "svelte.enable-ts-plugin" = true;
          "svelte.language-server.ls-path" = "${pkgs.svelte-language-server}/bin/svelte-language-server";
        };
        extensions = with pkgs; [
          vscode-marketplace.svelte.svelte-vscode
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "svelte"
      ];
    };
  };
}
