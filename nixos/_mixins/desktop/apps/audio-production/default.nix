{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment.systemPackages = with pkgs; [
    gnome.gnome-sound-recorder
    tenacity
  ];

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "org/gnome/SoundRecorder" = {
            audio-channel = "mono";
            audio-profile = "flac";
          };
        };
      }
    ];
  };
}
