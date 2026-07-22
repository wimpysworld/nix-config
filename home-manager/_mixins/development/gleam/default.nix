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
  home.packages = with pkgs; [
    glas
    gleam
  ];

  programs.zed-editor = lib.mkIf config.programs.zed-editor.enable {
    extensions = [
      "gleam"
    ];
  };

  claude-code.lspServers.gleam = {
    command = lib.getExe pkgs.glas;
    extensionToLanguage = {
      ".gleam" = "gleam";
    };
  };

  programs.fresh-editor.settings.lsp.gleam = {
    command = lib.getExe pkgs.glas;
    enabled = true;
    auto_start = true;
  };
}
