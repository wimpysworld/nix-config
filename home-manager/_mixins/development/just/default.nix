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
    # Packages that are used by some of the extensions below
    packages =
      with pkgs;
      [
        just
        just-formatter
      ]
      ++ lib.optional (!host.is.server) just-lsp;
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [ "just" ] ++ lib.optional (!host.is.server) "just-ls";
      userSettings = {
        languages = {
          Just = {
            formatter = {
              external = {
                command = "${pkgs.just-formatter}/bin/just-formatter";
              };
            };
            language_servers = lib.optionals (!host.is.server) [
              "just-lsp"
            ];
          };
        };
        lsp = lib.mkIf (!host.is.server) {
          just-lsp = { };
        };
      };
    };
  };
}
