{ lib, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
    "apps/audio-recorder" = {
      append-to-file = false;
      filename-pattern = "LMP-martin-%V-%H%M";
      folder-name = "/home/martin/Audio";
      keep-on-top = true;
      level-bar-value = 2;
      media-format = "Podcast Mono, Lossless 44KHz";
      #saved-profiles = [('CD Quality, AAC 44KHz', 'm4a', '', 'audio/x-raw,rate=44100,channels=2 ! avenc_aac compliance=-2 ! avmux_mp4'), ('CD Quality, Lossless 44KHz', 'flac', '', 'audio/x-raw,rate=44100,channels=2 ! flacenc name=enc'), ('CD Quality, Lossy 44KHz', 'ogg', '', 'audio/x-raw,rate=44100,channels=2 ! vorbisenc name=enc quality=0.5 ! oggmux'), ('CD Quality, MP3 Lossy 44KHz', 'mp3', '', 'audio/x-raw,rate=44100,channels=2 ! lamemp3enc name=enc target=0 quality=2'), ('Lossless WAV 22KHz', 'wav', '', 'audio/x-raw,rate=22050,channels=1 ! wavenc name=enc'), ('Lossless WAV 44KHz', 'wav', '', 'audio/x-raw,rate=44100,channels=2 ! wavenc name=enc'), ('Lossy Speex 32KHz', 'spx', '', 'audio/x-raw,rate=32000,channels=2 ! speexenc name=enc ! oggmux'), ('Podcast Mono, Lossless 44KHz', 'flac', '', 'audio/x-raw,rate=44100,channels=1 ! flacenc name=enc')];
      show-systray-icon = false;
      timer-active = false;
      timer-expanded = false;
      timer-text = "";
    };
  };
}
