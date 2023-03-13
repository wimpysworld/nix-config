{ desktop, pkgs, ... }: {
  imports = [
    (./. + "/${desktop}.nix")
  ];
}
