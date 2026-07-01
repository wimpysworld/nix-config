{
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  programs = {
    jq = {
      enable = true;
    };
    jqp = lib.mkIf (!host.is.server) {
      enable = true;
      settings = {
        theme = {
          name = "catppuccin-${config.catppuccin.flavor}";
        };
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "json5"
        "jsonl"
      ];
    };
  };
}
