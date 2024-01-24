{ pkgs, ... }: {
  imports = [
    ./avahi.nix
  ];
  services = {
    printing.enable = true;
    printing.drivers = with pkgs; [ gutenprint hplip ];
  };
}
