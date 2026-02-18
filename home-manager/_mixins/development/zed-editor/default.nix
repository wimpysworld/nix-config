{
  config,
  hostname,
  isWorkstation,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  fontSize = 18;
  fontWeight = 400;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && isWorkstation) {
  catppuccin.zed.enable = config.programs.zed-editor.enable;
  programs = {
    zed-editor = {
      enable = true;
      extensions = [
        "color-highlight"
        "comment"
        "dependi"
        "desktop"
        "dockerfile"
        "editorconfig"
        "ini"
        "make"
        "rainbow-csv"
        "semgrep"
        "vhs"
        "xml"
      ];
      installRemoteServer = true;
      package = pkgs.unstable.zed-editor;
      userSettings = {
        agent = {
          enable_feedback = false;
          dock = if hostname == "vader" then "bottom" else "right";
          message_editor_min_lines = 12;
        };
        agent_buffer_font_size = fontSize;
        agent_ui_font_size = fontSize;
        auto_update = false;
        base_keymap = "VSCode";
        buffer_font_size = fontSize;
        buffer_font_family = "FiraCode Nerd Font Mono";
        buffer_font_weight = fontWeight;
        colorize_brackets = true;
        cursor_shape = "block";
        hard_tabs = false;
        inlay_hints = {
          enabled = true;
        };
        minimap = {
          show = "auto";
          thumb = "always";
          thumb_border = "full";
          current_line_highlight = null;
        };
        lsp = {
          semgrep = {
            binary = {
              path = "${pkgs.semgrep}/bin/semgrep";
              arguments = [ "lsp" ];
            };
            initialization_options = {
              scan = {
                configuration = [ "auto" ];
                only_git_dirty = false;
              };
            };
          };
        };
        node = {
          ignore_system_version = true;
          path = "${pkgs.nodejs_24}/bin/node";
          npm_path = "${pkgs.nodejs_24}/bin/npm";
        };
        #session = {
        #  trust_all_worktrees = true;
        #};
        show_whitespaces = "all";
        tab_size = 2;
        tabs = {
          close_position = "right";
          file_icons = true;
          git_status = false;
          show_close_button = "hover";
          show_diagnostics = "all";
        };
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        terminal = {
          blinking = "on";
          copy_on_select = true;
          cursor_shape = "block";
          font_family = "FiraCode Nerd Font Mono";
          font_size = fontSize;
          max_scroll_history_lines = 16384;
        };
        title_bar = {
          show_branch_icon = true;
          show_branch_name = true;
          show_project_items = true;
          show_onboarding_banner = true;
          show_user_picture = true;
          #show_user_menu = true;
          show_sign_in = true;
          show_menus = true;
        };
        ui_font_family = "Work Sans";
        ui_font_size = fontSize;
        ui_font_weight = fontWeight;
        wrap_guides = [
          80
          88
        ];
      };
    };
  };
}
