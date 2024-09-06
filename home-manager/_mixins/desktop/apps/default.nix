{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  audioPlayer = [ "org.gnome.Decibels.desktop" ];
  archiveManager = [ "org.gnome.FileRoller.desktop" ];
  webBrowser = [ "brave-browser.desktop" ];
  documentViewer = [ "org.gnome.Papers.desktop" ];
  imageViewer = [ "org.gnome.Loupe.desktop" ];
  videoPlayer = [ "com.github.rafostar.Clapper.desktop" ];
in
{
  imports = [
    ./audio-production
    ./gitkraken
    ./internet-chat
    ./joplin
    ./meld
    ./obs-studio
    ./rhythmbox
    ./ulauncher
    ./vscode
    ./youtube-music
    ./zed-editor
  ];
  home.packages = with pkgs; lib.optionals isLinux [
    clapper                 # video player
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

        "audio/*" = audioPlayer;
        "image/*" = imageViewer;
        "video/*" = videoPlayer;
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
