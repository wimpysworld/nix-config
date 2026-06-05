{
  programs.vtm = {
    enable = true;

    settings.desktop.taskbar = {
      selected = "Term";
      clearItems = true;

      items = [
        {
          id = "Term";
          label = "Terminal";
          type = "dtvt";
          title = "Terminal";
          env = "EDITOR=fresh";
          cmd = "$0 -r term";
        }
      ];
    };
  };
}
