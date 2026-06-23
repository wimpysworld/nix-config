{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;

  matrixProfile = "personal";
  matrixUserId = "@wimpress:matrix.org";
  matrixHomeserver = "https://matrix.org";
in
{
  config = lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.linux && host.is.workstation) {
    programs.iamb = {
      enable = true;
      settings = {
        default_profile = matrixProfile;

        profiles.${matrixProfile} = {
          user_id = matrixUserId;
          url = matrixHomeserver;
        };

        layout = {
          style = "config";
          tabs = [
            {
              split = [
                { window = "iamb://rooms"; }
                { window = "iamb://dms"; }
              ];
            }
          ];
        };

        macros.normal = {
          C = ":chats<Enter>";
          D = ":dms<Enter>";
          R = ":rooms<Enter>";
          S = ":spaces<Enter>";
        };

        settings = {
          external_edit_file_suffix = ".md";
          log_level = "warn";
          message_shortcode_display = false;
          message_user_color = true;
          mouse.enabled = true;
          normal_after_send = false;
          reaction_display = true;
          reaction_shortcode_display = false;
          read_receipt_display = true;
          read_receipt_send = true;
          request_timeout = 180;
          state_event_display = false;
          tabstop = 2;
          typing_notice_display = true;
          typing_notice_send = true;
          user_gutter_width = 24;
          username_display = "displayname";

          image_preview = {
            protocol.type = "kitty";
            size = {
              height = 10;
              width = 66;
            };
          };

          notifications = {
            enabled = true;
            show_message = false;
            via = "desktop";
          };

          sort = {
            chats = [
              "favorite"
              "invite"
              "unread"
              "recent"
              "name"
            ];
            dms = [
              "favorite"
              "invite"
              "unread"
              "recent"
              "name"
            ];
            members = [
              "power"
              "server"
              "localpart"
            ];
            rooms = [
              "favorite"
              "invite"
              "unread"
              "recent"
              "name"
            ];
            spaces = [
              "favorite"
              "invite"
              "unread"
              "recent"
              "name"
            ];
          };
        };
      };
    };
  };
}
