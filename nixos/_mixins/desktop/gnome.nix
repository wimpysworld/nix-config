{ lib, pkgs, hostname,... }: {
  imports = [
    ./qt-style.nix
  ];

  environment.systemPackages = with pkgs; [
    eyedropper
    formatter
    gnome.gnome-tweaks
    gnome-usage
    gnomeExtensions.appindicator
    gnomeExtensions.autohide-battery
    gnomeExtensions.battery-time
    gnomeExtensions.dash-to-dock
    gnomeExtensions.emoji-copy
    gnomeExtensions.freon
    gnomeExtensions.hide-workspace-thumbnails
    gnomeExtensions.just-perfection
    gnomeExtensions.logo-menu
    gnomeExtensions.status-area-horizontal-spacing
    gnomeExtensions.tiling-assistant
    gnomeExtensions.wireless-hid
    gnomeExtensions.vitals
    gnomeExtensions.wifi-qrcode
    unstable.gnomeExtensions.workspace-switcher-manager
    usbimager
  ] ++ lib.optionals (hostname == "tanis" || hostname == "sidious") [
    gnomeExtensions.thinkpad-battery-threshold
  ];

  # Exclude the GNOME apps I don't use
  environment.gnome.excludePackages = (with pkgs; [
    baobab
    gnome-console
  ]) ++ (with pkgs.gnome; [
    geary
    gnome-music
    gnome-system-monitor
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
            switch-to-workspace-1=['<Control><Alt>1', '<Control><Alt>Home', '<Super>Home']
            switch-to-workspace-2=['<Control><Alt>2']
            switch-to-workspace-3=['<Control><Alt>3']
            switch-to-workspace-4=['<Control><Alt>4']
            switch-to-workspace-5=['<Control><Alt>5']
            switch-to-workspace-6=['<Control><Alt>6']
            switch-to-workspace-7=['<Control><Alt>7']
            switch-to-workspace-8=['<Control><Alt>8']
            switch-to-workspace-down=['<Control><Alt>Down']
            switch-to-workspace-last=['<Control><Alt>End', '<Super>End']
            switch-to-workspace-left=['<Control><Alt>Left', '<Super>Page_Up']
            switch-to-workspace-right=['<Control><Alt>Right', '<Super>Page_Down']
            switch-to-workspace-up=['<Control><Alt>Up']
            move-to-workspace-1=['<Super><Alt>1', '<Super><Alt>Home']
            move-to-workspace-2=['<Super><Alt>2']
            move-to-workspace-3=['<Super><Alt>3']
            move-to-workspace-4=['<Super><Alt>4']
            move-to-workspace-5=['<Super><Alt>5']
            move-to-workspace-6=['<Super><Alt>6']
            move-to-workspace-7=['<Super><Alt>7']
            move-to-workspace-8=['<Super><Alt>8']
            move-to-workspace-down=['<Super><Alt>Down']
            move-to-workspace-last=['<Super><Alt>End']
            move-to-workspace-left=['<Super><Alt>Left', '<Super><Shift>Page_Up']
            move-to-workspace-right=['<Super><Alt>Right', '<Super><Shift>Page_Down']
            move-to-workspace-up=["<Super><Alt>Up"]
            # Disable maximise/unmaximise because tiling-assistant extension handles it
            maximize=[]
            unmaximize=[]

            [org.gnome.desktop.wm.preferences]
            audible-bell=false
            button-layout=":minimize,maximize,close"
            num-workspaces=8
            titlebar-font="Work Sans Semi-Bold 12"
            workspace-names=[ "Web", "Work", "Chat", "Code", "Virt", "Cast", "Fun", "Stuff" ]

            [org.gnome.GWeather]
            temperature-unit="centigrade"

            [org.gnome.mutter]
            dynamic-workspaces=false
            # Disable Mutter edge-tiling because tiling-assistant extension handles it
            edge-tiling=false
            workspaces-only-on-primary=false

            [org.gnome.mutter.keybindings]
            # Disable Mutter toggle-tiled because tiling-assistant extension handles it
            toggle-tiled-left=[]
            toggle-tiled-right=[]

            [org.gnome.nautilus.preferences]
            default-folder-viewer="list-view"

            [org.gnome.settings-daemon.plugins.power]
            power-button-action="interactive"
            sleep-inactive-ac-timeout=0
            sleep-inactive-ac-type="nothing"

            [org.gnome.settings-daemon.plugins.xsettings]
            overrides={'Gtk/DialogsUseHeader': <0>, 'Gtk/ShellShowsAppMenu': <0>, 'Gtk/EnablePrimaryPaste': <0>, 'Gtk/DecorationLayout': <':minimize,maximize,close,menu'>, 'Gtk/ShowUnicodeMenu': <0>}

            [org.gnome.shell]
            enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'dash-to-dock@micxgx.gmail.com', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com', 'autohide-battery@sitnik.ru', 'just-perfection-desktop@just-perfection', 'wifiqrcode@glerro.pm.me', 'logomenu@aryan_k', 'status-area-horizontal-spacing@mathematical.coffee.gmail.com', 'emoji-copy@felipeftn', 'freon@UshakovVasilii_Github.yahoo.com', 'wireless-hid@chlumskyvaclav.gmail.com', 'batime@martin.zurowietz.de', 'workspace-switcher-manager@G-dH.github.com', 'hide-workspace-thumbnails@dylanmc.ca', 'Vitals@CoreCoding.com', 'tiling-assistant@leleat-on-github']

            [org.gnome.shell.extensions.auto-move-windows]
            application-list=['brave-browser.desktop:1', 'Wavebox.desktop:2', 'discord.desktop:2', 'org.telegram.desktop.desktop:3', 'nheko.desktop:3', 'code.desktop:4', 'GitKraken.desktop:4', 'com.obsproject.Studio.desktop:6']

            [org.gnome.shell.extensions.dash-to-dock]
            click-action="skip"
            disable-overview-on-startup=true
            dock-position="LEFT"
            hot-keys=true
            scroll-action = "cycle-windows"
            show-trash=false

            [org.gnome.shell.extensions.emoji-copy]
            always-show=false
            emoji-keybind=['<Primary><Alt>e']

            [org.gnome.shell.extensions.just-perfection]
            startup-status=0
            window-demands-attention-focus=true

            [org.gnome.shell.extensions.Logo-menu]
            menu-button-icon-image=23
            menu-button-system-monitor="${pkgs.gnome-usage}/bin/gnome-usage"
            menu-button-terminal="${pkgs.tilix}/bin/tilix"
            show-activities-button=true
            symbolic-icon=true

            [org.gnome.shell.extensions.thinkpad-battery-threshold]
            color-mode=false

            [org.gnome.shell.extensions.tiling-assistant]
            enable-advanced-experimental-features=true
            maximize-with-gap=true
            show-layout-panel-indicator=true
            single-screen-gap=10
            window-gap=10
            overridden-settings={'org.gnome.mutter.edge-tiling': <@mb nothing>, 'org.gnome.desktop.wm.keybindings.maximize': <@mb nothing>, 'org.gnome.desktop.wm.keybindings.unmaximize': <@mb nothing>, 'org.gnome.mutter.keybindings.toggle-tiled-left': <['<Super>Left']>, 'org.gnome.mutter.keybindings.toggle-tiled-right': <['<Super>Right']>}

            [org.gnome.shell.extensions.vitals]
            alphabetize=false
            fixed-widths=true
            include-static-info=false
            menu-centered=true
            monitor-cmd="${pkgs.gnome-usage}/bin/gnome-usage"
            network-speed-format=1
            show-fan=false
            show-temperature=false
            show-voltage=false
            update-time=2
            use-higher-precision=false

            [org.gnome.shell.extensions.wireless-hid]
            panel-box-index=4

            [org/gnome/shell/extensions/workspace-switcher-manager]
            active-show-ws-name=true
            active-show-app-name=false
            inactive-show-ws-name=true
            inactive-show-app-name=false

            [org.gtk.gtk4.Settings.FileChooser]
            clock-format="24h"

            [org.gtk.gtk4.settings.file-chooser]
            show-hidden=false
            show-size-column=true
            show-type-column=true
            sort-column="name"
            sort-directories-first=true
            sort-order="ascending"
            type-format="category"
            view-type="list"

            [org.gtk.Settings.FileChooser]
            clock-format="24h"

            [org.gtk.settings.file-chooser]
            show-hidden=false
            show-size-column=true
            show-type-column=true
            sort-column="name"
            sort-directories-first=true
            sort-order="ascending"
            type-format="category"
          '';
        };
      };
    };
  };
}
