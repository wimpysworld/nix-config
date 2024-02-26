{ desktop, lib, pkgs, ... }: {
  imports = [
    ./avahi.nix
  ];

  programs = lib.mkIf (desktop == "mate") {
    system-config-printer.enable = true;
  };

  services = {
    printing.enable = true;
    printing.drivers = with pkgs; [ gutenprint hplip ];
    system-config-printer.enable = true;
  };
}
