{ pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    vivaldi
    vivaldi-ffmpeg-codecs
  ];
}
