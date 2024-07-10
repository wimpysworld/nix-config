{ config, desktop, hostname, inputs, lib, pkgs, platform, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
  hasCUDA = lib.elem "cudaPackages.cudatoolkit" config.environment.systemPackages;
  hasOpenCL = config.hardware.amdgpu.opencl.enable;
in
{
  environment = {
    systemPackages = (with pkgs; lib.optionals (isWorkstation) [
      (blender.override {
        cudaSupport = hasCUDA;
        hipSupport = hasOpenCL;
      })
      brave
      celluloid
      davinci-resolve
      fractal
      gnome.dconf-editor
      gnome.gnome-sound-recorder
      google-chrome
      halloy
      inkscape
      libreoffice
      meld
      microsoft-edge
      pika-backup
      pinta
      shotcut
      tartube
      tenacity
      usbimager
      wavebox
      youtube-music
      zoom-us
    ] ++ lib.optionals (isWorkstation && desktop == "gnome") [
      gnome-extension-manager
      gnomeExtensions.start-overlay-in-application-view
      gnomeExtensions.tiling-assistant
      gnomeExtensions.vitals
    ]) ++ (with pkgs.unstable; lib.optionals (isWorkstation) [
      telegram-desktop
    ]) ++ (with inputs; lib.optionals (isWorkstation) [
      antsy-alien-attack-pico.packages.${platform}.default
    ]);
  };

  programs = {
    dconf.profiles.user.databases = [{
      settings = with lib.gvariant; lib.mkIf (isWorkstation) {
      };
    }];
  };

  users.users.martin = {
    description = "Martin Wimpress";
    # mkpasswd -m sha-512
    hashedPassword = "$6$UXNQ20Feu82wCFK9$dnJTeSqoECw1CGMSUdxKREtraO.Nllv3/fW9N3m7lPHYxFKA/Cf8YqYGDmiWNfaKeyx2DKdURo0rPYBrSZRL./";
  };

  systemd.tmpfiles.rules = [
    "d /mnt/snapshot/${username} 0755 ${username} users"
  ];
}
