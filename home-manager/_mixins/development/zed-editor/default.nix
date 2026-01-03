{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  fontSize = 18;
  fontWeight = 400;
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor && isLinux && isWorkstation) {
  catppuccin.zed.enable = config.programs.zed-editor.enable;
  home.packages = with pkgs; [
    clang-tools
    neocmakelsp
    vscode-css-languageserver
  ];
  programs = {
    zed-editor = {
      enable = true;
      extensions = [
        "color-highlight"
        "comment"
        "desktop"
        "dockerfile"
        "editorconfig"
        "ini"
        "make"
        "neocmake"
        "rainbow-csv"
        "vhs"
        "xml"
      ];
      package = pkgs.unstable.zed-editor;
      userSettings = {
        agent = {
          message_editor_min_lines = 5;
        };
        auto_update = false;
        base_keymap = "VSCode";
        buffer_font_size = fontSize;
        buffer_font_family = "FiraCode Nerd Font Mono";
        buffer_font_weight = fontWeight;
        colorize_brackets = true;
        features = {
          edit_prediction_provider = "copilot";
        };
        hard_tabs = false;
        hour_format = "hour24";
        insert_spaces = true;
        lsp_document_colors = "background";
        metrics = false;
        minimap = {
          show = "auto";
          thumb = "always";
          thumb_border = "full";
          current_line_highlight = null;
        };
        node = {
          ignore_system_version = true;
          path = "${pkgs.nodejs_24}/bin/node";
          npm_path = "${pkgs.nodejs_24}/bin/npm";
        };
        session = {
          trust_all_worktrees = true;
        };
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
          metrics = false;
          diagnostics = false;
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
          show_user_menu = true;
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
