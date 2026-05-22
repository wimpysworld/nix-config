{ lib }:

let
  paletteJson = builtins.fromJSON (builtins.readFile ./catppuccin-palette.json);

  flavours = [
    "latte"
    "frappe"
    "macchiato"
    "mocha"
  ];

  rgb =
    colours: name:
    let
      inherit (colours.${name}.rgb) r g b;
    in
    [
      r
      g
      b
    ];

  mkFreshTheme =
    flavour:
    let
      flavourData = paletteJson.${flavour};
      colours = flavourData.colors;
      isDark = flavourData.dark;
      c = rgb colours;

      editorBg = c "base";
      panelBg = c "mantle";
      floatingBg = if isDark then c "base" else c "mantle";
      overlayBg = if isDark then c "surface0" else c "mantle";
      deepBg = c "crust";
      raisedBg = c "surface0";
      currentLineBg = c "surface0";
      selectionBg = c "surface1";
      activeBg = c "surface1";
      afterEofBg = c "mantle";
      faint = c "surface2";
      muted = c "overlay0";

      accent = c "blue";
      secondaryAccent = c "mauve";
      onAccent = c "base";
      onPanel = c "text";
    in
    {
      name = "catppuccin-${flavour}";

      editor = {
        bg = editorBg;
        fg = onPanel;
        cursor = c "pink";
        inactive_cursor = muted;
        selection_bg = selectionBg;
        selection_modifier = null;
        current_line_bg = currentLineBg;
        line_number_fg = muted;
        line_number_bg = editorBg;
        diff_add_bg = raisedBg;
        diff_remove_bg = raisedBg;
        diff_add_highlight_bg = c "green";
        diff_remove_highlight_bg = c "red";
        diff_modify_bg = raisedBg;
        diff_add_collision_fg = onAccent;
        diff_remove_collision_fg = onAccent;
        diff_modify_collision_fg = onAccent;
        ruler_bg = currentLineBg;
        whitespace_indicator_fg = muted;
        after_eof_bg = afterEofBg;
      };

      ui = {
        tab_active_fg = onAccent;
        tab_active_bg = accent;
        tab_inactive_fg = onPanel;
        tab_inactive_bg = currentLineBg;
        tab_separator_bg = deepBg;
        tab_close_hover_fg = c "red";
        tab_hover_bg = raisedBg;

        menu_bg = panelBg;
        menu_fg = onPanel;
        menu_active_bg = activeBg;
        menu_active_fg = c "sky";
        menu_dropdown_bg = floatingBg;
        menu_dropdown_fg = onPanel;
        menu_highlight_bg = accent;
        menu_highlight_fg = onAccent;
        menu_border_fg = muted;
        menu_separator_fg = muted;
        menu_hover_bg = activeBg;
        menu_hover_fg = onPanel;
        menu_disabled_fg = muted;
        menu_disabled_bg = floatingBg;

        status_bar_fg = onAccent;
        status_bar_bg = accent;
        status_palette_fg = onAccent;
        status_palette_bg = secondaryAccent;
        status_lsp_on_fg = onAccent;
        status_lsp_on_bg = c "green";
        status_lsp_actionable_fg = onAccent;
        status_lsp_actionable_bg = c "yellow";

        prompt_fg = onAccent;
        prompt_bg = c "green";
        prompt_selection_fg = onAccent;
        prompt_selection_bg = accent;

        popup_border_fg = accent;
        popup_bg = overlayBg;
        popup_selection_bg = accent;
        text_input_selection_bg = accent;
        popup_selection_fg = onAccent;
        popup_text_fg = onPanel;

        suggestion_bg = overlayBg;
        suggestion_selected_bg = accent;

        help_bg = editorBg;
        help_fg = onPanel;
        help_key_fg = c "sky";
        help_separator_fg = muted;
        help_indicator_fg = c "red";
        help_indicator_bg = editorBg;

        inline_code_bg = raisedBg;
        split_separator_fg = muted;
        split_separator_hover_fg = accent;
        scrollbar_track_fg = panelBg;
        scrollbar_thumb_fg = activeBg;
        scrollbar_track_hover_fg = raisedBg;
        scrollbar_thumb_hover_fg = muted;
        compose_margin_bg = editorBg;
        semantic_highlight_bg = raisedBg;
        semantic_highlight_modifier = [ "bold" ];
        terminal_bg = editorBg;
        terminal_fg = onPanel;

        status_warning_indicator_bg = c "yellow";
        status_warning_indicator_fg = onAccent;
        status_error_indicator_bg = c "red";
        status_error_indicator_fg = onAccent;
        status_warning_indicator_hover_bg = c "peach";
        status_warning_indicator_hover_fg = onAccent;
        status_error_indicator_hover_bg = c "maroon";
        status_error_indicator_hover_fg = onAccent;

        tab_drop_zone_bg = accent;
        tab_drop_zone_border = c "sapphire";
        settings_selected_bg = activeBg;
        settings_selected_fg = onPanel;

        file_status_added_fg = c "green";
        file_status_modified_fg = c "yellow";
        file_status_deleted_fg = c "red";
        file_status_renamed_fg = c "sky";
        file_status_untracked_fg = muted;
        file_status_conflicted_fg = c "maroon";
      };

      search = {
        match_bg = c "yellow";
        match_fg = onAccent;
        label_bg = secondaryAccent;
        label_fg = onAccent;
      };

      diagnostic = {
        error_fg = c "red";
        error_bg = raisedBg;
        warning_fg = c "yellow";
        warning_bg = raisedBg;
        info_fg = c "sky";
        info_bg = raisedBg;
        hint_fg = faint;
        hint_bg = raisedBg;
      };

      syntax = {
        keyword = c "pink";
        string = c "yellow";
        comment = c "overlay0";
        function = c "green";
        type = c "sky";
        variable = onPanel;
        constant = c "mauve";
        operator = c "pink";
        punctuation_bracket = onPanel;
        punctuation_delimiter = onPanel;
      };
    };

in
{
  inherit flavours mkFreshTheme;

  themes = builtins.listToAttrs (
    map (flavour: {
      name = "catppuccin-${flavour}";
      value = mkFreshTheme flavour;
    }) flavours
  );
}
