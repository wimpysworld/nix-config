{ desktop, inputs, lib, pkgs, platform, username, ... }:
let
  installFor = [ "martin" ];
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (lib.elem "${username}" installFor && isWorkstation) {
  environment = {
    systemPackages = with pkgs; [
      inputs.quickemu.packages.${platform}.default
      inputs.quickgui.packages.${platform}.default
    ];
  };
  virtualisation = {
    spiceUSBRedirection.enable = true;
  };
}
