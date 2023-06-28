{ pkgs, ... }: {
  imports = [
    ../../desktop/browsers.nix
    ../../desktop/obs-studio.nix
    ../../desktop/quickemu.nix
  ];

  environment.systemPackages = with pkgs; [
    authy
    cider
    gimp-with-plugins
    gnome.dconf-editor
    inkscape
    libreoffice
    maestral-gui
    meld
    pavucontrol
    rhythmbox
    shotcut
    slack
    # Fast moving apps use the unstable branch
    unstable.discord
    unstable.gitkraken
    unstable.tdesktop
    unstable.vscode-fhs
    unstable.zoom-us
  ];
}
