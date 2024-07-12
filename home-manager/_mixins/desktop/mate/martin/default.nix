{ lib, ... }:
{
  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings = with lib.hm.gvariant; {
    "net/launchpad/plank/docks/dock1" = {
      dock-items = [
        "brave-browser.dockitem"
        "Wavebox.dockitem"
        "org.telegram.desktop.dockitem"
        "discord.dockitem"
        "org.gnome.Fractal.dockitem"
        "org.squidowl.halloy.dockitem"
        "code.dockitem"
        "GitKraken.dockitem"
        "com.obsproject.Studio.dockitem"
      ];
    };

    "org/mate/desktop/applications/terminal" = {
      exec = "alacritty";
    };

    "org/mate/desktop/peripherals/keyboard/kbd" = {
      options = [
        "terminate\tterminate:ctrl_alt_bksp"
        "caps\tcaps:none"
      ];
    };

    "org/mate/marco/general" = {
      num-workspaces = mkInt32 8;
    };

    "org/mate/marco/workspace-names" = {
      name-1 = " Web ";
      name-2 = " Work ";
      name-3 = " Chat ";
      name-4 = " Code ";
      name-5 = " Term ";
      name-6 = " Cast ";
      name-7 = " Virt ";
      name-8 = " Fun ";
    };
  };
}
