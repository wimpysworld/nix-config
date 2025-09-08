{
  inputs,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem "${username}" installFor && isWorkstation) {
  environment = {
    systemPackages = with pkgs; [
      qemu
      inputs.quickemu.packages.${pkgs.system}.default
      # TODO: Fix and enable
      #inputs.quickgui.packages.${pkgs.system}.default
    ];
  };
  virtualisation = {
    spiceUSBRedirection.enable = true;
  };
}
