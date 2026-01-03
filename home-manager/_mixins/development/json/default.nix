{
  config,
  lib,
  ...
}:
{
  programs = {
    jq = {
      enable = true;
    };
    jqp = {
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
