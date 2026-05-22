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
      c = rgb colours;

      isDark = flavourData.dark;
      onAccent = if isDark then c "base" else c "text";
      onPanel = c "text";
      muted = c "subtext0";
      faint = c "overlay0";
      border = c "surface2";
      separator = c "surface0";
      editorBg = c "base";
      panelBg = c "mantle";
      recessedBg = c "crust";
      raisedBg = c "surface0";
      hoverBg = c "surface1";
      activeBg = c "surface2";
      selectionBg = c "surface1";
      accent = c "blue";
      secondaryAccent = c "mauve";
    in
    {
      name = "catppuccin-${flavour}";

      editor = {
        bg = editorBg;
        fg = onPanel;
        cursor = c "rosewater";
        inactive_cursor = faint;
        selection_bg = selectionBg;
        selection_modifier = null;
        current_line_bg = panelBg;
        line_number_fg = faint;
        line_number_bg = editorBg;
        diff_add_bg = raisedBg;
        diff_remove_bg = raisedBg;
        diff_add_highlight_bg = c "green";
        diff_remove_highlight_bg = c "red";
        diff_modify_bg = raisedBg;
        diff_add_collision_fg = onAccent;
        diff_remove_collision_fg = onAccent;
        diff_modify_collision_fg = onAccent;
        ruler_bg = raisedBg;
        whitespace_indicator_fg = faint;
        after_eof_bg = editorBg;
      };

      ui = {
        tab_active_fg = onAccent;
        tab_active_bg = accent;
        tab_inactive_fg = muted;
        tab_inactive_bg = panelBg;
        tab_separator_bg = recessedBg;
        tab_close_hover_fg = c "red";
        tab_hover_bg = hoverBg;

        menu_bg = panelBg;
        menu_fg = onPanel;
        menu_active_bg = activeBg;
        menu_active_fg = onPanel;
        menu_dropdown_bg = panelBg;
        menu_dropdown_fg = onPanel;
        menu_highlight_bg = accent;
        menu_highlight_fg = onAccent;
        menu_border_fg = border;
        menu_separator_fg = separator;
        menu_hover_bg = hoverBg;
        menu_hover_fg = onPanel;
        menu_disabled_fg = faint;
        menu_disabled_bg = recessedBg;

        status_bar_fg = onAccent;
        status_bar_bg = accent;
        status_palette_fg = onAccent;
        status_palette_bg = secondaryAccent;
        status_lsp_on_fg = onAccent;
        status_lsp_on_bg = c "green";
        status_lsp_actionable_fg = onAccent;
        status_lsp_actionable_bg = c "yellow";

        prompt_fg = onPanel;
        prompt_bg = panelBg;
        prompt_selection_fg = onAccent;
        prompt_selection_bg = accent;

        popup_border_fg = border;
        popup_bg = panelBg;
        popup_selection_bg = accent;
        text_input_selection_bg = selectionBg;
        popup_selection_fg = onAccent;
        popup_text_fg = onPanel;

        suggestion_bg = panelBg;
        suggestion_selected_bg = accent;

        help_bg = editorBg;
        help_fg = onPanel;
        help_key_fg = c "sky";
        help_separator_fg = separator;
        help_indicator_fg = c "red";
        help_indicator_bg = editorBg;

        inline_code_bg = raisedBg;
        split_separator_fg = border;
        split_separator_hover_fg = accent;
        scrollbar_track_fg = recessedBg;
        scrollbar_thumb_fg = activeBg;
        scrollbar_track_hover_fg = raisedBg;
        scrollbar_thumb_hover_fg = c "overlay2";
        compose_margin_bg = recessedBg;
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
        settings_selected_bg = accent;
        settings_selected_fg = onAccent;

        file_status_added_fg = c "green";
        file_status_modified_fg = c "yellow";
        file_status_deleted_fg = c "red";
        file_status_renamed_fg = c "blue";
        file_status_untracked_fg = c "teal";
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
        hint_fg = muted;
        hint_bg = raisedBg;
      };

      syntax = {
        keyword = c "mauve";
        string = c "green";
        comment = c "overlay1";
        function = c "blue";
        type = c "yellow";
        variable = onPanel;
        constant = c "peach";
        operator = c "sky";
        punctuation_bracket = c "overlay2";
        punctuation_delimiter = c "overlay2";
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
