{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  audioPlayer = [ "org.gnome.Decibels.desktop" ];
  archiveManager = [ "org.gnome.FileRoller.desktop" ];
  webBrowser = [ "brave-browser.desktop" ];
  documentViewer = [ "org.gnome.Papers.desktop" ];
  imageViewer = [ "org.gnome.Loupe.desktop" ];
  videoPlayer = [ "net.baseart.Glide.desktop" ];
in
{
  imports = [
    ./audio-production
    ./game-dev
    ./gitkraken
    ./heynote
    ./internet-chat
    ./jan
    ./joplin
    ./meld
    ./music
    ./obs-studio
    ./rhythmbox
    ./ulauncher
    ./vscode
    ./zed-editor
  ];
  home.packages = with pkgs; lib.optionals isLinux [
    glide-media-player      # video player
    unstable.decibels       # audio player
    gnome.gnome-calculator  # calcualtor
    loupe                   # image viewer
    papers                  # document viewer
  ];
  xdg = lib.mkIf isLinux {
    enable = true;
    mime.enable = true;
    mimeApps = {
      enable = true;
      associations.added = {
        "application/x-7z-compressed" = archiveManager;
        "application/x-7z-compressed-tar" = archiveManager;
        "application/x-bzip" = archiveManager;
        "application/x-bzip-compressed-tar" = archiveManager;
        "application/x-compress" = archiveManager;
        "application/x-compressed-tar" = archiveManager;
        "application/x-cpio" = archiveManager;
        "application/x-gzip" = archiveManager;
        "application/x-lha" = archiveManager;
        "application/x-lzip" = archiveManager;
        "application/x-lzip-compressed-tar" = archiveManager;
        "application/x-lzma" = archiveManager;
        "application/x-lzma-compressed-tar" = archiveManager;
        "application/x-tar" = archiveManager;
        "application/x-tarz" = archiveManager;
        "application/x-xar" = archiveManager;
        "application/x-xz" = archiveManager;
        "application/x-xz-compressed-tar" = archiveManager;
        "application/zip" = archiveManager;
        "application/gzip" = archiveManager;
        "application/bzip2" = archiveManager;
        "application/vnd.rar" = archiveManager;

        "application/x-extension-htm" = webBrowser;
        "application/x-extension-html" = webBrowser;
        "application/x-extension-shtml" = webBrowser;
        "application/x-extension-xht" = webBrowser;
        "application/x-extension-xhtml" = webBrowser;
        "application/xhtml+xml" = webBrowser;
        "text/html" = webBrowser;
        "x-scheme-handler/about" = webBrowser;
        "x-scheme-handler/ftp" = webBrowser;
        "x-scheme-handler/http" = webBrowser;
        "x-scheme-handler/https" = webBrowser;
        "x-scheme-handler/unknown" = webBrowser;

        "application/vnd.comicbook-rar" = documentViewer;
        "application/vnd.comicbook+zip" = documentViewer;
        "application/x-cb7" = documentViewer;
        "application/x-cbr" = documentViewer;
        "application/x-cbt" = documentViewer;
        "application/x-cbz" = documentViewer;
        "application/x-ext-cb7" = documentViewer;
        "application/x-ext-cbr" = documentViewer;
        "application/x-ext-cbt" = documentViewer;
        "application/x-ext-cbz" = documentViewer;
        "application/x-ext-djv" = documentViewer;
        "application/x-ext-djvu" = documentViewer;
        "image/vnd.djvu" = documentViewer;
        "application/pdf" = documentViewer;
        "application/x-bzpdf" = documentViewer;
        "application/x-ext-pdf" = documentViewer;
        "application/x-gzpdf" = documentViewer;
        "application/x-xzpdf" = documentViewer;
        "application/postscript" = documentViewer;
        "application/x-bzpostscript" = documentViewer;
        "application/x-gzpostscript" = documentViewer;
        "application/x-ext-eps" = documentViewer;
        "application/x-ext-ps" = documentViewer;
        "image/x-bzeps" = documentViewer;
        "image/x-eps" = documentViewer;
        "image/x-gzeps" = documentViewer;
        "image/tiff" = documentViewer;
        "application/oxps" = documentViewer;
        "application/vnd.ms-xpsdocument" = documentViewer;
        "application/illustrator" = documentViewer;

        #audio/3gpp;audio/3gpp2;audio/aac;audio/ac3;audio/AMR;audio/AMR-WB;audio/basic;audio/dv;audio/eac3;audio/flac;audio/m4a;audio/midi;audio/mp1;audio/mp2;audio/mp3;audio/mp4;audio/mpeg;audio/mpegurl;audio/mpg;audio/ogg;audio/opus;audio/prs.sid;audio/scpls;audio/vnd.rn-realaudio;audio/wav;audio/webm;audio/x-aac;audio/x-aiff;audio/x-ape;audio/x-flac;audio/x-gsm;audio/x-it;audio/x-m4a;audio/x-matroska;audio/x-mod;audio/x-mp1;audio/x-mp2;audio/x-mp3;audio/x-mpg;audio/x-mpeg;audio/x-mpegurl;audio/x-ms-asf;audio/x-ms-asx;audio/x-ms-wax;audio/x-ms-wma;audio/x-musepack;audio/x-pn-aiff;audio/x-pn-au;audio/x-pn-realaudio;audio/x-pn-realaudio-plugin;audio/x-pn-wav;audio/x-pn-windows-acm;audio/x-realaudio;audio/x-real-audio;audio/x-s3m;audio/x-sbc;audio/x-scpls;audio/x-shorten;audio/x-speex;audio/x-stm;audio/x-tta;audio/x-wav;audio/x-wavpack;audio/x-vorbis;audio/x-vorbis+ogg;audio/x-xm;
        "audio/mpeg" = audioPlayer;
        "audio/wav" = audioPlayer;
        "audio/x-aac" = audioPlayer;
        "audio/x-aiff" = audioPlayer;
        "audio/x-ape" = audioPlayer;
        "audio/x-flac" = audioPlayer;
        "audio/x-m4a" = audioPlayer;
        "audio/x-m4b" = audioPlayer;
        "audio/x-mp1" = audioPlayer;
        "audio/x-mp2" = audioPlayer;
        "audio/x-mp3" = audioPlayer;
        "audio/x-mpg" = audioPlayer;
        "audio/x-mpeg" = audioPlayer;
        "audio/x-mpegurl" = audioPlayer;
        "audio/x-opus+ogg" = audioPlayer;
        "audio/x-pn-aiff" = audioPlayer;
        "audio/x-pn-au" = audioPlayer;
        "audio/x-pn-wav" = audioPlayer;
        "audio/x-speex" = audioPlayer;
        "audio/x-vorbis" = audioPlayer;
        "audio/x-vorbis+ogg" = audioPlayer;
        "audio/x-wavpack" = audioPlayer;

        "image/jpeg" = imageViewer;
        "image/png" = imageViewer;
        "image/gif" = imageViewer;
        "image/webp" = imageViewer;
        "image/x-tga" = imageViewer;
        "image/vnd-ms.dds" = imageViewer;
        "image/x-dds" = imageViewer;
        "image/bmp" = imageViewer;
        "image/vnd.microsoft.icon" = imageViewer;
        "image/vnd.radiance" = imageViewer;
        "image/x-exr" = imageViewer;
        "image/x-portable-bitmap" = imageViewer;
        "image/x-portable-graymap" = imageViewer;
        "image/x-portable-pixmap" = imageViewer;
        "image/x-portable-anymap" = imageViewer;
        "image/x-qoi;image/svg+xml" = imageViewer;
        "image/svg+xml-compressed" = imageViewer;
        "image/avif" = imageViewer;
        "image/heic" = imageViewer;
        "image/jxl" = imageViewer;

        "application/mxf" = videoPlayer;
        "application/ogg" = videoPlayer;
        "application/ram" = videoPlayer;
        "application/sdp" = videoPlayer;
        "application/smil" = videoPlayer;
        "application/smil+xml" = videoPlayer;
        "application/vnd.apple.mpegurl" = videoPlayer;
        "application/vnd.ms-asf" = videoPlayer;
        "application/vnd.ms-wpl" = videoPlayer;
        "application/vnd.rn-realmedia" = videoPlayer;
        "application/vnd.rn-realmedia-vbr" = videoPlayer;
        "application/x-extension-mp4" = videoPlayer;
        "application/x-flash-video" = videoPlayer;
        "application/x-matroska" = videoPlayer;
        "application/x-netshow-channel" = videoPlayer;
        "application/x-ogg" = videoPlayer;
        "application/x-quicktime-media-link" = videoPlayer;
        "application/x-quicktimeplayer" = videoPlayer;
        "application/x-shorten" = videoPlayer;
        "application/x-smil" = videoPlayer;
        "application/xspf+xml" = videoPlayer;
        "video/3gp" = videoPlayer;
        "video/3gpp" = videoPlayer;
        "video/3gpp2" = videoPlayer;
        "video/dv" = videoPlayer;
        "video/divx" = videoPlayer;
        "video/fli" = videoPlayer;
        "video/mp2t" = videoPlayer;
        "video/mp4" = videoPlayer;
        "video/mp4v-es" = videoPlayer;
        "video/mpeg" = videoPlayer;
        "video/mpeg-system" = videoPlayer;
        "video/msvideo" = videoPlayer;
        "video/ogg" = videoPlayer;
        "video/quicktime" = videoPlayer;
        "video/vivo" = videoPlayer;
        "video/vnd.divx" = videoPlayer;
        "video/vnd.rn-realvideo" = videoPlayer;
        "video/vnd.vivo" = videoPlayer;
        "video/webm" = videoPlayer;
        "video/x-anim" = videoPlayer;
        "video/x-avi" = videoPlayer;
        "video/x-flc" = videoPlayer;
        "video/x-fli" = videoPlayer;
        "video/x-flic" = videoPlayer;
        "video/x-flv" = videoPlayer;
        "video/x-m4v" = videoPlayer;
        "video/x-matroska" = videoPlayer;
        "video/x-mpeg" = videoPlayer;
        "video/x-mpeg2" = videoPlayer;
        "video/x-ms-asf" = videoPlayer;
        "video/x-ms-asf-plugin" = videoPlayer;
        "video/x-ms-asx" = videoPlayer;
        "video/x-msvideo" = videoPlayer;
        "video/x-ms-wm" = videoPlayer;
        "video/x-ms-wmv" = videoPlayer;
        "video/x-ms-wmx" = videoPlayer;
        "video/x-ms-wvx" = videoPlayer;
        "video/x-nsv" = videoPlayer;
        "video/x-ogm+ogg" = videoPlayer;
        "video/x-theora" = videoPlayer;
        "video/x-theora+ogg" = videoPlayer;
        "video/x-totem-stream" = videoPlayer;
        "x-content/video-dvd" = videoPlayer;
        "x-content/video-vcd" = videoPlayer;
        "x-content/video-svcd" = videoPlayer;
        "x-scheme-handler/pnm" = videoPlayer;
        "x-scheme-handler/net" = videoPlayer;
        "x-scheme-handler/rtmp" = videoPlayer;
        "x-scheme-handler/mmsh" = videoPlayer;
        "x-scheme-handler/uvox" = videoPlayer;
        "x-scheme-handler/icy" = videoPlayer;
        "x-scheme-handler/icyx" = videoPlayer;
      };
      defaultApplications = {
        "audio/*" = audioPlayer;
        "application/pdf" = documentViewer;
        "image/*" = imageViewer;
        "text/html" = webBrowser;
        "video/*" = videoPlayer;
      };
    };
  };
}
