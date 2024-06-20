{ config, desktop, hostname, inputs, lib, pkgs, platform, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
in
{
  environment = {
    # Desktop environment applications/features I don't use or want
    gnome.excludePackages = with pkgs; [
      baobab
      gnome-console
      gnome-text-editor
      gnome.epiphany
      gnome.geary
      gnome.gnome-music
      gnome.gnome-system-monitor
      gnome.totem
    ];

    mate.excludePackages = with pkgs; [
      mate.caja-dropbox
      mate.eom
      mate.mate-themes
      mate.mate-netbook
      mate.mate-icon-theme
      mate.mate-backgrounds
      mate.mate-icon-theme-faenza
    ];

    pantheon.excludePackages = with pkgs; [
      pantheon.elementary-code
      pantheon.elementary-music
      pantheon.elementary-photos
      pantheon.elementary-videos
      pantheon.epiphany
    ];

    systemPackages = (with pkgs; [
      _1password
      lastpass-cli
    ] ++ lib.optionals (isWorkstation) [
      _1password-gui
      brave
      celluloid
      element-desktop
      fractal
      gimp-with-plugins
      gnome.dconf-editor
      gnome.gnome-sound-recorder
      google-chrome
      halloy
      inkscape
      libreoffice
      meld
      microsoft-edge
      opera
      pika-backup
      tartube
      tenacity
      usbimager
      vivaldi
      vivaldi-ffmpeg-codecs
      wavebox
      zoom-us
    ] ++ lib.optionals (isWorkstation && (desktop == "gnome" || desktop == "pantheon")) [
      loupe
      marker
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
