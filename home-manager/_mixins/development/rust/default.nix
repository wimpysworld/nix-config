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
      rust-analyzer
    ];
  };

  claude-code.lspServers.rust = {
    command = lib.getExe pkgs.rust-analyzer;
    extensionToLanguage = {
      ".rs" = "rust";
    };
  };

  programs.fresh-editor.settings.lsp.rust = {
    command = lib.getExe pkgs.rust-analyzer;
    enabled = true;
    auto_start = true;
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "cargotom"
        "tombi"
        "toml"
      ];
    };
  };
}
