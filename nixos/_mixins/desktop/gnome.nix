{ pkgs, ... }: {
  imports = [
    ./qt-style.nix
  ];

  environment.systemPackages = with pkgs; [
    eyedropper
    formatter
    gnome.gnome-tweaks
    gnomeExtensions.appindicator
    gnomeExtensions.autohide-battery
    gnomeExtensions.dash-to-dock
    gnomeExtensions.emoji-copy
    gnomeExtensions.just-perfection
    gnomeExtensions.logo-menu
    #gnomeExtensions.maccy-menu
    gnomeExtensions.status-area-horizontal-spacing
    #gnomeExtensions.useless-gaps
    gnomeExtensions.wayland-or-x11
    gnomeExtensions.wifi-qrcode
    gnomeExtensions.wireless-hid
    usbimager
  ];

  # Exclude the GNOME apps I don't use
  environment.gnome.excludePackages = (with pkgs; [
    gnome-console
  ]) ++ (with pkgs.gnome; [
    geary
    gnome-music
    epiphany
    totem
  ]);

  programs = {
    calls.enable = false;
    evince.enable = true;
    file-roller.enable = true;
    geary.enable = false;
    gnome-disks.enable = true;
    gnome-terminal.enable = false;
    seahorse.enable = true;
  };

  services = {
    gnome = {
      games.enable = false;
    };
    udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
    xserver = {
      enable = true;
      displayManager = {
        gdm.enable = true;
      };

      desktopManager = {
        gnome = {
          enable = true;
          favoriteAppsOverride = ''
            [org.gnome.shell]
            favorite-apps=[ 'brave-browser.desktop', 'authy.desktop', 'Wavebox.desktop', 'org.telegram.desktop.desktop', 'discord.desktop', 'nheko.desktop', 'code.desktop', 'GitKraken.desktop', 'com.obsproject.Studio.desktop' ]
          '';
          # List all the available schemas:
          # $ gsettings list-schemas
          # Display a list of all keys and values for a schema:
          # $ gsettings list-recursively <schema-name>
          extraGSettingsOverrides = ''
            [org.gnome.desktop.datetime]
            automatic-timezone=true

            [org.gnome.desktop.input-sources]
            xkb-options=[ "grp:alt_shift_toggle", "caps:none" ]

            [org.gnome.desktop.interface]
            clock-format="24h"
            clock-show-weekday=true
            color-scheme="prefer-dark"
            cursor-size=32
            #cursor-theme="elementary"
            document-font-name="Work Sans 12"
            font-name="Work Sans 12"
            #gtk-theme="io.elementary.stylesheet.bubblegum"
            gtk-enable-primary-paste=true
            #icon-theme="elementary"
            monospace-font-name="FiraCode Nerd Font Medium 13"
            text-scaling-factor=1.0

            [org.gnome.desktop.peripherals.touchpad]
            tap-to-click=true

            [org.gnome.desktop.session]
            idle-delay=900

            [org.gnome.desktop.sound]
            theme-name="freedesktop"

            [org.gnome.desktop.wm.keybindings]
            switch-to-workspace-left=[ "<Primary><Alt>Left" ]
            switch-to-workspace-right=[ "<Primary><Alt>Right" ]

            [org.gnome.desktop.wm.preferences]
            audible-bell=false
            button-layout=":minimize,maximize,close"
            num-workspaces=8
            titlebar-font="Work Sans Semi-Bold 12"
            workspace-names=[ "Web", "Work", "Chat", "Code", "Virt", "Cast", "Fun", "Stuff" ]

            [org.gnome.GWeather]
            temperature-unit="centigrade"

            [org.gnome.mutter]
            workspaces-only-on-primary=false
            dynamic-workspaces=false

            [org.gnome.mutter.keybindings]
            toggle-tiled-left=[ "<Super>Left" ]
            toggle-tiled-right=[ "<Super>Right" ]

            [org.gnome.nautilus.preferences]
            default-folder-viewer="list-view"

            [org.gnome.settings-daemon.plugins.power]
            power-button-action="interactive"
            sleep-inactive-ac-timeout=0
            sleep-inactive-ac-type="nothing"

            [org.gnome.settings-daemon.plugins.xsettings]
            overrides={'Gtk/DialogsUseHeader': <0>, 'Gtk/ShellShowsAppMenu': <0>, 'Gtk/EnablePrimaryPaste': <0>, 'Gtk/DecorationLayout': <':minimize,maximize,close,menu'>, 'Gtk/ShowUnicodeMenu': <0>}

            [org.gnome.shell]
            enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'dash-to-dock@micxgx.gmail.com', 'workspace-indicator@gnome-shell-extensions.gcampax.github.com', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com', 'autohide-battery@sitnik.ru', 'just-perfection-desktop@just-perfection', 'waylandorx11@injcristianrojas.github.com', 'wifiqrcode@glerro.pm.me', 'wireless-hid@chlumskyvaclav.gmail.com', 'logomenu@aryan_k', 'status-area-horizontal-spacing@mathematical.coffee.gmail.com' ]

            [org.gnome.shell.extensions.dash-to-dock]
            disable-overview-on-startup=true
            dock-position="LEFT"
            hot-keys=false
            show-trash=false

            [org.gnome.shell.extensions.auto-move-windows]
            application-list=['brave-browser.desktop:1', 'Wavebox.desktop:2', 'discord.desktop:2', 'org.telegram.desktop.desktop:3', 'nheko.desktop:3', 'code.desktop:4', 'GitKraken.desktop:4', 'com.obsproject.Studio.desktop:6']

            [org.gnome.shell.extensions.just-perfection]
            startup-status=0
            window-demands-attention-focus=true

            [org.gnome.shell.extensions.Logo-menu]
            menu-button-icon-image=23
            menu-button-terminal="tilix"
            show-activities-button=true
            symbolic-icon=true

            [org.gtk.gtk4.Settings.FileChooser]
            clock-format="24h"

            [org.gtk.Settings.FileChooser]
            clock-format="24h"
          '';
        };
      };
    };
  };
}
