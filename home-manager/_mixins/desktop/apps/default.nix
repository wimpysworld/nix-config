{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  nautilusExtensionDir = "${pkgs.nautilus-python}/lib/nautilus/extensions-4";
  audioPlayer = [ "org.gnome.Decibels.desktop" ];
  archiveManager = [ "org.gnome.FileRoller.desktop" ];
  webBrowser =
    if noughtyLib.hostHasTag "cg" then [ "google-chrome.desktop" ] else [ "brave-browser.desktop" ];
  # Browser mimetypes are shared between added associations and default
  # applications so URL handlers resolve without a desktop session.
  browserMimeTypes = lib.genAttrs [
    "application/x-extension-htm"
    "application/x-extension-html"
    "application/x-extension-shtml"
    "application/x-extension-xht"
    "application/x-extension-xhtml"
    "application/xhtml+xml"
    "text/html"
    "x-scheme-handler/about"
    "x-scheme-handler/ftp"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/unknown"
  ] (_: webBrowser);
  documentViewer = [ "org.gnome.Papers.desktop" ];
  # kitty and Zed also claim inode/directory, so folders need an explicit
  # default or xdg-open can pick a terminal.
  fileManager = [ "org.gnome.Nautilus.desktop" ];
  imageViewer = [ "org.gnome.Loupe.desktop" ];
  videoPlayer = [ "io.github.celluloid_player.Celluloid.desktop" ];
  textEditor = [ "dev.zed.Zed.desktop" ];
  vectorEditor = [ "org.inkscape.Inkscape.desktop" ];
  ebookReader = [ "com.github.johnfactotum.Foliate.desktop" ];
  wordProcessor = [ "writer.desktop" ];
  spreadsheet = [ "calc.desktop" ];
  presentation = [ "impress.desktop" ];
  # mimeapps.list does not expand wildcards such as audio/*, so the audio,
  # image and video types are listed one by one. Each set is shared between
  # added associations and default applications, so xdg-mime agrees with GIO.
  #audio/3gpp;audio/3gpp2;audio/aac;audio/ac3;audio/AMR;audio/AMR-WB;audio/basic;audio/dv;audio/eac3;audio/flac;audio/m4a;audio/midi;audio/mp1;audio/mp2;audio/mp3;audio/mp4;audio/mpeg;audio/mpegurl;audio/mpg;audio/ogg;audio/opus;audio/prs.sid;audio/scpls;audio/vnd.rn-realaudio;audio/wav;audio/webm;audio/x-aac;audio/x-aiff;audio/x-ape;audio/x-flac;audio/x-gsm;audio/x-it;audio/x-m4a;audio/x-matroska;audio/x-mod;audio/x-mp1;audio/x-mp2;audio/x-mp3;audio/x-mpg;audio/x-mpeg;audio/x-mpegurl;audio/x-ms-asf;audio/x-ms-asx;audio/x-ms-wax;audio/x-ms-wma;audio/x-musepack;audio/x-pn-aiff;audio/x-pn-au;audio/x-pn-realaudio;audio/x-pn-realaudio-plugin;audio/x-pn-wav;audio/x-pn-windows-acm;audio/x-realaudio;audio/x-real-audio;audio/x-s3m;audio/x-sbc;audio/x-scpls;audio/x-shorten;audio/x-speex;audio/x-stm;audio/x-tta;audio/x-wav;audio/x-wavpack;audio/x-vorbis;audio/x-vorbis+ogg;audio/x-xm;
  audioMimeTypes = lib.genAttrs [
    "audio/flac"
    "audio/mp4"
    "audio/mpeg"
    "audio/ogg"
    "audio/opus"
    "audio/wav"
    "audio/x-aac"
    "audio/x-aiff"
    "audio/x-ape"
    "audio/x-flac"
    "audio/x-m4a"
    "audio/x-m4b"
    "audio/x-mp1"
    "audio/x-mp2"
    "audio/x-mp3"
    "audio/x-mpg"
    "audio/x-mpeg"
    "audio/x-mpegurl"
    "audio/x-opus+ogg"
    "audio/x-pn-aiff"
    "audio/x-pn-au"
    "audio/x-pn-wav"
    "audio/x-speex"
    "audio/x-vorbis"
    "audio/x-vorbis+ogg"
    "audio/x-wav"
    "audio/x-wavpack"
  ] (_: audioPlayer);
  imageMimeTypes = lib.genAttrs [
    "image/apng"
    "image/jpeg"
    "image/jp2"
    "image/png"
    "image/gif"
    "image/webp"
    "image/x-tga"
    "image/vnd-ms.dds"
    "image/x-dds"
    "image/bmp"
    "image/vnd.microsoft.icon"
    "image/vnd.radiance"
    "image/x-exr"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-portable-anymap"
    "image/qoi"
    "image/x-qoi"
    "image/svg+xml"
    "image/svg+xml-compressed"
    "image/tiff"
    "image/avif"
    "image/heic"
    "image/jxl"
    "image/x-win-bitmap"
    "image/x-xbitmap"
    "image/x-xpixmap"
  ] (_: imageViewer);
  videoMimeTypes = lib.genAttrs [
    "application/mxf"
    "application/ogg"
    "application/ram"
    "application/sdp"
    "application/smil"
    "application/smil+xml"
    "application/vnd.apple.mpegurl"
    "application/vnd.ms-asf"
    "application/vnd.ms-wpl"
    "application/vnd.rn-realmedia"
    "application/vnd.rn-realmedia-vbr"
    "application/x-extension-mp4"
    "application/x-flash-video"
    "application/x-matroska"
    "application/x-netshow-channel"
    "application/x-ogg"
    "application/x-quicktime-media-link"
    "application/x-quicktimeplayer"
    "application/x-shorten"
    "application/x-smil"
    "application/xspf+xml"
    "video/3gp"
    "video/3gpp"
    "video/3gpp2"
    "video/dv"
    "video/divx"
    "video/fli"
    "video/flv"
    "video/mp2t"
    "video/mp4"
    "video/mp4v-es"
    "video/mpeg"
    "video/mpeg-system"
    "video/msvideo"
    "video/ogg"
    "video/quicktime"
    "video/vivo"
    "video/vnd.divx"
    "video/vnd.mpegurl"
    "video/vnd.rn-realvideo"
    "video/vnd.vivo"
    "video/webm"
    "video/x-anim"
    "video/x-avi"
    "video/x-flc"
    "video/x-fli"
    "video/x-flic"
    "video/x-flv"
    "video/x-m4v"
    "video/x-matroska"
    "video/x-mpeg"
    "video/x-mpeg-system"
    "video/x-mpeg2"
    "video/x-ms-asf"
    "video/x-ms-asf-plugin"
    "video/x-ms-asx"
    "video/x-msvideo"
    "video/x-ms-wm"
    "video/x-ms-wmv"
    "video/x-ms-wmx"
    "video/x-ms-wvx"
    "video/x-nsv"
    "video/x-ogm+ogg"
    "video/x-theora"
    "video/x-theora+ogg"
    "video/x-totem-stream"
    "x-content/video-dvd"
    "x-content/video-vcd"
    "x-content/video-svcd"
    "x-scheme-handler/pnm"
    "x-scheme-handler/net"
    "x-scheme-handler/rtmp"
    "x-scheme-handler/mmsh"
    "x-scheme-handler/uvox"
    "x-scheme-handler/icy"
    "x-scheme-handler/icyx"
  ] (_: videoPlayer);
  # Contour claims application/x-executable, a parent type of many scripting
  # languages, so source code needs explicit defaults or it opens in a terminal.
  textEditorMimeTypes = lib.genAttrs [
    "application/javascript"
    "application/json"
    "application/x-perl"
    "application/x-ruby"
    "application/x-sh"
    "application/x-shellscript"
    "application/xml"
    "text/javascript"
    "text/plain"
    "text/x-lua"
    "text/x-perl"
    "text/x-python"
    "text/x-python3"
    "text/x-ruby"
    "text/xml"
  ] (_: textEditor);
  # The session bus finds the D-Bus service files these apps ship in the Home
  # profile through XDG_DATA_DIRS, set by PAM on NixOS and by
  # targets.genericLinux elsewhere, so no dbus.packages registration is needed.
  desktopApps = with pkgs; [
    celluloid # video player
    dconf-editor # dconf GUI editor
    decibels # audio player
    file-roller # archive manager
    gcr # pinentry-gnome3 may not work on non-GNOME systems, without gcr registered on D-Bus
    gnome-calculator # calculator
    gnome-disk-utility # disk utility
    gnome-font-viewer # font viewer
    loupe # image viewer
    nautilus # file manager
    papers # document viewer
    resources # monitor system resources
    seahorse # encryption and key manager
    sushi # file previewer
    system-config-printer # printer configuration
  ];
in
{
  imports = [
    ./browsers
    ./chat
    ./media-production
    ./music
    ./notes
    ./office
    ./rustdesk
    ./streaming
    ./terminal
    ./utilities
    ./voice
  ];

  dconf = lib.mkIf (host.is.linux && host.is.workstation) {
    settings = with lib.hm.gvariant; {
      "ca/desrt/dconf-editor" = {
        show-warning = false;
      };
      "io/github/celluloid-player/celluloid" = {
        csd-enable = false;
        dark-theme-enable = catppuccinPalette.isDark;
      };
    };
  };
  home = lib.mkIf (host.is.linux && host.is.workstation) {
    packages =
      with pkgs;
      [
        nautilus-python
        nautilus-open-any-terminal
      ]
      ++ desktopApps;
    sessionVariables = {
      NAUTILUS_4_EXTENSION_DIR = lib.mkDefault nautilusExtensionDir;
    };
  };
  # D-Bus activation starts Nautilus with the systemd environment, so it needs
  # the extension directory there too.
  systemd.user.sessionVariables = lib.mkIf (host.is.linux && host.is.workstation) {
    NAUTILUS_4_EXTENSION_DIR = lib.mkDefault nautilusExtensionDir;
  };

  xdg = lib.mkIf (host.is.linux && host.is.workstation) {
    enable = true;
    mime.enable = true;
    mimeApps = {
      enable = true;
      associations.added =
        browserMimeTypes
        // {
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
          "application/illustrator" = documentViewer;
        }
        // audioMimeTypes
        // imageMimeTypes
        // videoMimeTypes;
      defaultApplications =
        browserMimeTypes
        // audioMimeTypes
        // imageMimeTypes
        // videoMimeTypes
        // textEditorMimeTypes
        // {
          "inode/directory" = fileManager;
          "application/pdf" = documentViewer;
          # Papers cannot open PostScript or EPS, so Inkscape opens them.
          "application/postscript" = vectorEditor;
          "image/x-eps" = vectorEditor;
          "application/epub+zip" = ebookReader;
          # ChatGPT claims the Office Open XML types, so office documents need
          # explicit defaults.
          "application/msword" = wordProcessor;
          "application/rtf" = wordProcessor;
          "application/vnd.oasis.opendocument.text" = wordProcessor;
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = wordProcessor;
          "application/vnd.ms-excel" = spreadsheet;
          "application/vnd.oasis.opendocument.spreadsheet" = spreadsheet;
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = spreadsheet;
          "text/csv" = spreadsheet;
          "application/vnd.ms-powerpoint" = presentation;
          "application/vnd.oasis.opendocument.presentation" = presentation;
          "application/vnd.openxmlformats-officedocument.presentationml.presentation" = presentation;
          # Fastmail must be registered as the browser's email handler for
          # mailto links to open in Fastmail.
          "x-scheme-handler/mailto" = webBrowser;
        };
    };
  };
}
