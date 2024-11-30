{
  lib,
  isInstall,
  pkgs,
  ...
}:
{
  environment = {
    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        evolutionWithPlugins
      ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "org/gnome/evolution/mail" = {
            search-gravatar-for-photo = true;
            show-sender-photo = true;
            send-recv-all-on-start = true;
            junk-check-incoming = false;
            junk-lookup-addressbook = true;
            junk-check-custom-header = false;
            composer-mode = "markdown";
            composer-magic-smileys = true;
            composer-outlook-filenames = true;
            composer-use-outbox = true;
            composer-delay-outbox-flush = mkUint32 1;
            composer-word-wrap-length = mkUint32 72;
            composer-signature-in-new-only = true;
            composer-ignore-list-reply-to = true;
            composer-group-reply-to-list = true;
            forward-style-name = "quoted";
            forward-style = mkUint32 2;
            reply-style-name = "quoted";
            reply-style = mkUint32 0;
            preview-unset-html-colors = true;
            load-http-images = mkUint32 2;
            notify-remote-content = false;
            show-attachment-bar = false;
            use-custom-font = true;
            monospace-font = "FiraCode Nerd Font Mono Medium 16";
            variable-width-font = "Work Sans 16";
          };
          "org/gnome/evolution/shell" = {
            webkit-minimum-font-size = mkUint32 16;
          };
          "org/gnome/evolution/calendar" = {
            use-24hour-format = true;
            day-end-hour = mkUint32 18;
            day-end-minute = mkUint32 0;
            allow-direct-summary-edit = true;
            use-markdown-editor = true;
            week-view-days-left-to-right = true;
            hide-completed-tasks = true;
            hide-completed-tasks-value = mkUint32 7;
            use-default-reminder = true;
            default-reminder-interval = mkUint32 10;
            contacts-reminder-enabled = true;
            contacts-reminder-units = "days";
            contacts-reminder-interval = mkUint32 7;
            delete-meeting-on-decline = false;
          };
          "org/gnome/evolution/addressbook" = {
            completion-show-address = true;
          };
          "org/gnome/evolution/plugin/itip" = {
            show-message-description = true;
            attach-components = true;
          };
          "org/gnome/evolution/plugin/prefer-plain" = {
            mode = "prefer_plain";
          };

          #"org/gnome/evolution/plugin/external-editor" = {
          #  command = "pluma";
          #};
        };
      }
    ];
    evolution.enable = isInstall;
  };

  # Enable services to round out the desktop
  services = {
    gnome.evolution-data-server.enable = lib.mkForce isInstall;
  };
}
