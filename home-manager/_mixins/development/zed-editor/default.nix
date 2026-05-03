{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  fontSize = 18;
  fontWeight = 400;

  # Extensions whose `auto_install_extensions` flag is explicitly `false`.
  # Zed will not reinstall them, but it also does not delete the on-disk
  # directory if the user previously installed via the UI; the
  # `zedDisabledExtensionsPurge` activation hook below handles that.
  disabledExtensions = lib.attrNames (
    lib.filterAttrs (_: v: v == false) (
      config.programs.zed-editor.userSettings.auto_install_extensions or { }
    )
  );

  zedExtensionsDir = "${config.xdg.dataHome}/zed/extensions/installed";
  zedExtensionsIndex = "${config.xdg.dataHome}/zed/extensions/index.json";
  zedExtensionsWorkDir = "${config.xdg.dataHome}/zed/extensions/work";
  zedExternalAgentsDir = "${config.xdg.dataHome}/zed/external_agents";
in
lib.mkIf host.is.workstation {
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
        "vhs"
        "xml"
      ];
      installRemoteServer = !host.is.darwin;
      package = if host.is.darwin then null else pkgs.unstable.zed-editor;
      userSettings = {
        agent = {
          enable_feedback = false;
          dock = if host.display.primaryIsPortrait then "bottom" else "right";
          message_editor_min_lines = 12;
        };
        agent_buffer_font_size = fontSize;
        agent_ui_font_size = fontSize;
        # Suppress the bundled OpenCode extension; the ACP adapter
        # configured by `agentic/acp` registers the same agent, and
        # leaving the extension installed surfaces a duplicate entry in
        # Zed's External Agents pane.
        auto_install_extensions = {
          opencode = false;
        };
        auto_update = false;
        base_keymap = "VSCode";
        buffer_font_size = fontSize;
        buffer_font_family = "FiraCode Nerd Font Mono";
        buffer_font_weight = fontWeight;
        colorize_brackets = true;
        cursor_shape = "block";
        format_on_save = "off";
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
        node = {
          ignore_system_version = true;
          path = "${pkgs.nodejs}/bin/node";
          npm_path = "${pkgs.nodejs}/bin/npm";
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

  # Fully purge extensions whose `auto_install_extensions` entry is
  # explicitly `false`. A simple `rm -rf` of the install directory is
  # not enough: Zed reads `~/.local/share/zed/extensions/index.json`
  # synchronously at startup BEFORE walking the filesystem, and uses
  # that cached index to register external agents, languages, themes
  # and icon themes. A stale entry there resurrects the extension's
  # external-agent registration on every launch, surfacing a ghost
  # `[E]` row in the External Agents pane even though the install tree
  # is gone. The hook therefore removes four locations per disabled
  # extension:
  #
  #   1. `extensions/installed/<id>/`  - the extension contents
  #   2. `extensions/work/<id>/`       - wasm runtime workspace
  #   3. `external_agents/<id>/`       - cached agent binary archive
  #   4. `extensions/index.json`       - surgical per-extension edit
  #                                       via `jq`, atomic tempfile mv
  #
  # The index edit uses the same shape as `agentic/acp`'s settings
  # purge: precheck file existence, precheck JSON validity, write to a
  # tempfile, atomic `mv` on success, `rm` on failure. We deliberately
  # avoid deleting `index.json` wholesale so other (still-installed)
  # extensions are not disturbed. Running after `linkGeneration` means
  # the desired settings are already on disk by the time we clean up.
  home.activation.zedDisabledExtensionsPurge = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    jq=${lib.getExe pkgs.jq}
    ${lib.concatMapStringsSep "\n" (ext: ''
      ext=${lib.escapeShellArg ext}

      # 1. Installed extension tree.
      installed=${lib.escapeShellArg zedExtensionsDir}/"$ext"
      if [[ -d "$installed" ]]; then
        ${pkgs.coreutils}/bin/rm -rf "$installed"
      fi

      # 2. wasm runtime workspace (absent for ACP-only extensions).
      work=${lib.escapeShellArg zedExtensionsWorkDir}/"$ext"
      if [[ -d "$work" ]]; then
        ${pkgs.coreutils}/bin/rm -rf "$work"
      fi

      # 3. Cached agent binary archive.
      agents=${lib.escapeShellArg zedExternalAgentsDir}/"$ext"
      if [[ -d "$agents" ]]; then
        ${pkgs.coreutils}/bin/rm -rf "$agents"
      fi

      # 4. Drop stale references from the cached extension index.
      #    Zed reads this synchronously at startup BEFORE checking
      #    the filesystem, so leaving it in place re-registers the
      #    extension's external agents even though the install dir
      #    is gone.
      index=${lib.escapeShellArg zedExtensionsIndex}
      if [[ -f "$index" ]] && "$jq" -e . "$index" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp "$index.XXXXXX")"
        if "$jq" --arg id "$ext" '
          del(.extensions[$id])
          | .languages    |= with_entries(select(.value.extension != $id))
          | .themes       |= with_entries(select(.value.extension != $id))
          | .icon_themes  |= with_entries(select(.value.extension != $id))
        ' "$index" > "$tmp"; then
          ${pkgs.coreutils}/bin/mv "$tmp" "$index"
        else
          ${pkgs.coreutils}/bin/rm -f "$tmp"
        fi
      fi
    '') disabledExtensions}
  '';
}
