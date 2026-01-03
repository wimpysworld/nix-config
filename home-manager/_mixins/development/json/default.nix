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
      userSettings = {
        overrides = [
          {
            files = [ "*.jsonc" ];
            options = {
              parser = "json";
              trailingComma = "none";
            };
          }
        ];
        extensions = [
          "json5"
          "jsonl"
        ];
      };
    };
  };
}
