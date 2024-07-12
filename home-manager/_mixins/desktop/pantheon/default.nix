{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.file = {
    ".local/share/plank/themes/Catppuccin-mocha/dock.theme".text = builtins.readFile ../../configs/plank-catppuccin-mocha.theme;
    "${config.xdg.configHome}/autostart/monitor.desktop".text = ''
      [Desktop Entry]
      Name=Monitor Indicators
      Comment=Monitor Indicators
      Type=Application
      Exec=/run/current-system/sw/bin/com.github.stsdc.monitor --start-in-background
      Icon=com.github.stsdc.monitor
      Categories=
      Terminal=false
      StartupNotify=false'';
  };

  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
  };

  systemd.user.services = {
    # https://github.com/tom-james-watson/emote
    emote = {
      Unit = {
        Description = "Emote";
      };
      Service = {
        ExecStart = "${pkgs.emote}/bin/emote";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
