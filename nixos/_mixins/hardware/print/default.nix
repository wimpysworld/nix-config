{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
lib.mkIf (!host.is.iso) {
  # Only enables auxilary printing support/packages if
  # config.services.printing.enable is true; the master control
  # - https://wiki.nixos.org/wiki/Printing
  programs.system-config-printer = lib.mkIf config.services.printing.enable {
    enable = if (host.desktop == "hyprland") then true else false;
  };
  services = {
    printing = {
      enable = true;
      drivers =
        with pkgs;
        lib.optionals config.services.printing.enable [
          gutenprint
          hplip
        ];
      webInterface = false;
    };
    system-config-printer.enable = config.services.printing.enable;
  };
}
