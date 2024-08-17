{
  config,
  desktop,
  isInstall,
  lib,
  pkgs,
  ...
}:
lib.mkIf isInstall {
  # Only enables auxilary printing support/packages if
  # config.services.printing.enable is true; the master control
  # - https://wiki.nixos.org/wiki/Printing
  programs.system-config-printer = lib.mkIf config.services.printing.enable {
    enable = if (desktop == "mate" || desktop == "hyprland") then true else false;
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
