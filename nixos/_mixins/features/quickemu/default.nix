{ desktop, hostname, inputs, lib, pkgs, platform, ... }:
let
  notVM = if (hostname == "minimech" || hostname == "scrubber" || builtins.substring 0 5 hostname == "lima-") then false else true;
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (isInstall) {
  environment = {
    systemPackages = (with pkgs; lib.optionals (isWorkstation && notVM) [
      inputs.quickemu.packages.${platform}.default
      inputs.quickgui.packages.${platform}.default
    ]);
  };
  virtualisation = {
    spiceUSBRedirection.enable = true;
  };
}
