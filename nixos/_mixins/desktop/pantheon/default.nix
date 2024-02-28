{ hostname, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
{
  # Exclude the elementary apps I don't use
  environment = {
    pantheon.excludePackages = with pkgs.pantheon; [
      elementary-code
      elementary-music
      elementary-photos
      elementary-videos
      epiphany
    ];

    # App indicator
    # - https://discourse.nixos.org/t/anyone-with-pantheon-de/28422
    # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
    pathsToLink = [ "/libexec" ];

    # Add additional apps and include Yaru for syntax highlighting
    systemPackages = with pkgs; [
      loupe
      yaru-theme
    ] ++ lib.optionals (isInstall) [
      appeditor
      formatter
      gnome.gnome-clocks
      gnome.simple-scan
      pick-colour-picker
      usbimager
    ];
  };

  # Add GNOME Disks, Pantheon Tweaks and Seahorse
  programs = {
    gnome-disks.enable = isInstall;
    pantheon-tweaks.enable = isInstall;
    seahorse.enable = isInstall;
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  services = {
    gnome.gnome-keyring.enable = true;
    gvfs.enable = true;
    xserver = {
      enable = true;
      displayManager = {
        lightdm.enable = true;
        lightdm.greeters.pantheon.enable = true;
      };

      desktopManager = {
        gnome = {
          # List all the available schemas:
          # $ gsettings list-schemas
          # Display a list of all keys and values for a schema:
          # $ gsettings list-recursively <schema-name>
          extraGSettingsOverrides = ''
            [org.gnome.desktop.datetime]
            automatic-timezone=true

            [org.gnome.desktop.input-sources]
            xkb-options=[ "grp:alt_shift_toggle" "caps:none" ]

            [org.gnome.desktop.interface]
            clock-format="24h"
            color-scheme="prefer-dark"
            cursor-size=32
            cursor-theme="elementary"
            document-font-name="Work Sans 12"
            font-name="Work Sans 12"
            gtk-theme="io.elementary.stylesheet.bubblegum"
            gtk-enable-primary-paste=true
            icon-theme="elementary"
            monospace-font-name="FiraCode Nerd Font Medium 13"
            text-scaling-factor=1.0

            [org.gnome.desktop.session]
            idle-delay=900

            [org.gnome.desktop.sound]
            theme-name="elementary"

            [org.gnome.desktop.wm.keybindings]
            switch-to-workspace-left=[ "<Primary><Alt>Left" ]
            switch-to-workspace-right=[ "<Primary><Alt>Right" ]

            [org.gnome.desktop.wm.preferences]
            audible-bell=false
            button-layout=":minimize,maximize,close"
            num-workspaces=8
            titlebar-font="Work Sans Semi-Bold 12"
            workspace-names=[ "Web" "Work" "Chat" "Code" "Virt" "Cast" "Fun" "Stuff" ]

            [org.gnome.GWeather]
            temperature-unit="centigrade"

            [org.gnome.mutter]
            workspaces-only-on-primary=false
            dynamic-workspaces=false

            [org.gnome.mutter.keybindings]
            toggle-tiled-left=[ "<Super>Left" ]
            toggle-tiled-right=[ "<Super>Right" ]

            [org.gnome.settings-daemon.plugins.power]
            power-button-action="interactive"
            sleep-inactive-ac-timeout=0
            sleep-inactive-ac-type="nothing"

            [org.gtk.gtk4.Settings.FileChooser]
            clock-format="24h"

            [org.gtk.Settings.FileChooser]
            clock-format="24h"
          '';
        };
        pantheon = {
          enable = true;
          extraGSettingsOverrides = ''
            [com.github.stsdc.monitor.settings]
            background-state=true
            indicator-state=true
            indicator-cpu-state=false
            indicator-gpu-state=false
            indicator-memory-state=false
            indicator-network-download-state=true
            indicator-network-upload-state=true
            indicator-temperature-state=true

            [desktop.ibus.panel]
            show-icon-on-systray=false
            use-custom-font=true
            custom-font="Work Sans 10"

            [desktop.ibus.panel.emoji]
            font="JoyPixels 16"

            [io.elementary.code.saved-state]
            outline-visible=true

            [io.elementary.desktop.agent-geoclue2]
            location-enabled=true

            [io.elementary.desktop.wingpanel]
            use-transparency=false

            [io.elementary.desktop.wingpanel.datetime]
            clock-format="24h"

            [io.elementary.desktop.wingpanel.sound]
            max-volume=100.0

            [io.elementary.files.preferences]
            singleclick-select=true

            [io.elementary.notifications.applications.gala-other]
            remember=false
            sounds=false

            [io.elementary.settings-daemon.datetime]
            show-weeks=true

            [io.elementary.settings-daemon.housekeeping]
            cleanup-downloads-folder=false

            [io.elementary.terminal.settings]
            audible-bell=false
            background="rgb(18,18,20)"
            cursor-color="rgb(255,182,56)"
            follow-last-tab=true
            font="FiraCode Nerd Font Medium 13"
            foreground="rgb(200,200,200)"
            natural-copy-paste=false
            palette="rgb(20,20,23):rgb(214,43,43):rgb(65,221,117):rgb(255,182,56):rgb(40,169,255):rgb(230,109,255):rgb(20,229,211):rgb(200,200,200):rgb(67,67,69):rgb(222,86,86):rgb(161,238,187):rgb(255,219,156):rgb(148,212,255):rgb(243,182,255):rgb(161,245,238):rgb(233,233,233)"
            theme="custom"
            unsafe-paste-alert=false

            [net.launchpad.plank.dock.settings]
            alignment="center"
            hide-mode="window-dodge"
            icon-size=48
            pinned-only=false
            position="left"
            theme="Transparent"

            [org.gnome.desktop.wm.keybindings]
            switch-to-workspace-1=['<Control><Alt>1', '<Control><Alt>Home']
            switch-to-workspace-2=['<Control><Alt>2']
            switch-to-workspace-3=['<Control><Alt>3']
            switch-to-workspace-4=['<Control><Alt>4']
            switch-to-workspace-5=['<Control><Alt>5']
            switch-to-workspace-6=['<Control><Alt>6']
            switch-to-workspace-7=['<Control><Alt>7']
            switch-to-workspace-8=['<Control><Alt>8']
            switch-to-workspace-down=['<Control><Alt>Down']
            switch-to-workspace-last=['<Control><Alt>End']
            switch-to-workspace-left=['<Control><Alt>Left']
            switch-to-workspace-right=['<Control><Alt>Right']
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
            move-to-workspace-left=['<Super><Alt>Left']
            move-to-workspace-right=['<Super><Alt>Right']
            move-to-workspace-up=["<Super><Alt>Up"]

            [org.pantheon.desktop.gala.appearance]
            button-layout=":minimize,maximize,close"

            [org.pantheon.desktop.gala.behavior]
            dynamic-workspaces=false
            overlay-action="io.elementary.wingpanel --toggle-indicator=app-launcher"

            [org.pantheon.desktop.gala.mask-corners]
            enable=false
          '';
          extraWingpanelIndicators = with pkgs; [
            monitor
            wingpanel-indicator-ayatana
          ];
        };
      };
    };
  };

  # App indicator
  # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
  systemd.user.services.indicator-application-service = {
    description = "indicator-application-service";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.indicator-application-gtk3}/libexec/indicator-application/indicator-application-service";
    };
  };

  xdg.portal = {
    config = {
      pantheon = {
        default = [
          "pantheon"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };
  };
}
