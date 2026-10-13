{ lib, pkgs, ... }:
{
  options.wayland.windowManager.mango = {
    enable = lib.mkEnableOption "MangoWM";
    package = lib.mkPackageOption pkgs "mango" { };
    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (
          either (oneOf [
            bool
            int
            float
            str
          ]) (listOf str)
        );
      default = { };
      description = "MangoWM configuration keys. A list renders one line per element, for repeated keys such as `bind` and `window_rule`.";
    };
    keymodes = lib.mkOption {
      type = with lib.types; attrsOf (listOf str);
      default = { };
      description = "Key mode names mapped to complete binding lines, rendered after the default-mode lines.";
    };
    # Home Manager's way-displays module writes `systemd.variables` on every
    # `wayland.windowManager` entry, so the option must exist. The session
    # environment comes from the compositor contract through
    # `wayland-session start`, not from this list.
    systemd.variables = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Unused. Declared for Home Manager modules that set it on every window manager.";
    };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Lines appended to the end of the MangoWM configuration.";
    };
  };
}
