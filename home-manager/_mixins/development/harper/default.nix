# Harper - privacy-first grammar and spelling checking.
# Centralised configuration for editor integrations.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  lspEnabled = !host.is.server;
  harperLs = "${pkgs.harper}/bin/harper-ls";

  # Shared user dictionary seeded across every host from a plaintext word list,
  # one term per line. The list is read-only in the Nix store, so add new terms
  # to dictionary.txt rather than via the editor code action.
  harperDictionary = ./dictionary.txt;

  harperSettings = {
    dialect = "British";
    diagnosticSeverity = "hint";
    userDictPath = "${harperDictionary}";
    # Disable em dash and en dash suggestions across every integration.
    linters = {
      Dashes = false;
    };
  };
in
{
  home.packages = lib.optional lspEnabled pkgs.harper;

  # Fresh Editor - universal grammar and spelling LSP.
  programs.fresh-editor.settings.universal_lsp.harper = lib.mkIf lspEnabled {
    command = harperLs;
    args = [ "--stdio" ];
    enabled = true;
    auto_start = true;
    only_features = [ "diagnostics" ];
    initialization_options = {
      "harper-ls" = harperSettings;
    };
  };

  # Zed Editor - extension and LSP settings.
  programs.zed-editor = lib.mkIf (lspEnabled && config.programs.zed-editor.enable) {
    extensions = [ "harper" ];
    userSettings.lsp."harper-ls" = {
      binary = {
        path = harperLs;
        arguments = [ "--stdio" ];
      };
      settings."harper-ls" = harperSettings;
    };
  };
}
