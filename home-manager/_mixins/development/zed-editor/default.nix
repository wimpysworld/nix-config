{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  fontSize = 18;
  fontWeight = 400;

  # ─── External agents (ACP) ────────────────────────────────────────────
  # Each agent mixin (claude-code, codex, opencode) only declares that it
  # is enabled. Zed-side wiring lives here so the structure of Zed's
  # `settings.json` stays owned by a single module. Agent binaries come
  # from numtide's llm-agents flake, the same input the agent mixins use,
  # which keeps the ACP adapters version-pinned alongside their CLIs.
  inherit (pkgs.stdenv.hostPlatform) system;
  acpPackages = inputs.llm-agents.packages.${system};

  # `agent_servers` table emitted into Zed's userSettings. Each entry is
  # gated on its agent mixin being enabled; disabling the mixin removes
  # the entry from the Nix-rendered settings, and the activation hook
  # below drops any stale on-disk copy that Home Manager's deep-merge
  # would otherwise preserve.
  acpAgentServers =
    lib.optionalAttrs config.programs.claude-code.enable {
      Claude = {
        type = "custom";
        command = "${acpPackages.claude-agent-acp}/bin/claude-agent-acp";
        args = [ ];
        env = { };
      };
    }
    // lib.optionalAttrs config.programs.codex.enable {
      Codex = {
        type = "custom";
        command = "${acpPackages.codex-acp}/bin/codex-acp";
        args = [ ];
        env = { };
      };
    }
    // lib.optionalAttrs config.programs.opencode.enable {
      OpenCode = {
        type = "custom";
        command = "${config.programs.opencode.package}/bin/opencode";
        args = [ "acp" ];
        env = { };
      };
    };

  # Keymap shortcuts for `agent::NewExternalAgentThread`. `lib.optional`
  # returns a 0- or 1-element list, so the `++` chain produces a single
  # flat list that exactly matches the enabled set above.
  acpKeymaps =
    lib.optional config.programs.claude-code.enable {
      bindings = {
        "ctrl-alt-shift-c" = [
          "agent::NewExternalAgentThread"
          {
            agent = {
              custom = {
                name = "Claude";
              };
            };
          }
        ];
      };
    }
    ++ lib.optional config.programs.codex.enable {
      bindings = {
        "ctrl-alt-shift-x" = [
          "agent::NewExternalAgentThread"
          {
            agent = {
              custom = {
                name = "Codex";
              };
            };
          }
        ];
      };
    }
    ++ lib.optional config.programs.opencode.enable {
      bindings = {
        "ctrl-alt-shift-o" = [
          "agent::NewExternalAgentThread"
          {
            agent = {
              custom = {
                name = "OpenCode";
              };
            };
          }
        ];
      };
    };

  # Names we expect to see in Zed's `agent_servers` table after activation.
  # Anything else under that key is treated as stale and purged.
  managedAgentServers = lib.attrNames acpAgentServers;

  # Extensions whose `auto_install_extensions` flag is explicitly `false`.
  # Zed will not reinstall them, but it also does not delete the on-disk
  # directory if the user previously installed via the UI; the second
  # activation hook handles that.
  disabledExtensions = lib.attrNames (
    lib.filterAttrs (_: v: v == false) (
      config.programs.zed-editor.userSettings.auto_install_extensions or { }
    )
  );

  zedSettingsPath = "${config.xdg.configHome}/zed/settings.json";
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
      userKeymaps = acpKeymaps;
      userSettings = {
        agent = {
          enable_feedback = false;
          dock = if host.display.primaryIsPortrait then "bottom" else "right";
          message_editor_min_lines = 12;
        };
        agent_buffer_font_size = fontSize;
        agent_ui_font_size = fontSize;
        agent_servers = acpAgentServers;
        # Suppress the bundled OpenCode extension; the ACP adapter above
        # registers the same agent, and leaving the extension installed
        # surfaces a duplicate entry in Zed's External Agents pane.
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

  # Purge stale entries from Zed's `agent_servers` table before the
  # upstream `zedSettingsActivation` hook merges Nix-generated settings
  # into the on-disk file. Home Manager merges with `jq '$dynamic *
  # $static'`, which is a deep merge: top-level keys on disk that the
  # Nix config no longer emits are kept forever. For `agent_servers`
  # that leaks renamed or disabled agents (e.g. the old `claude-acp`
  # and `codex-acp` entries) into Zed's External Agents pane.
  #
  # `managedAgentServers` is the source of truth; anything else under
  # `agent_servers` gets dropped. Other top-level keys are left
  # untouched so users can still tweak settings via Zed's UI.
  #
  # The second hook fully purges extensions whose
  # `auto_install_extensions` entry is explicitly `false`. A simple
  # `rm -rf` of the install directory is not enough: Zed reads
  # `~/.local/share/zed/extensions/index.json` synchronously at
  # startup BEFORE walking the filesystem, and uses that cached index
  # to register external agents, languages, themes and icon themes.
  # A stale entry there resurrects the extension's external-agent
  # registration on every launch, surfacing a ghost `[E]` row in the
  # External Agents pane even though the install tree is gone. The
  # hook therefore removes four locations per disabled extension:
  #
  #   1. `extensions/installed/<id>/`  - the extension contents
  #   2. `extensions/work/<id>/`       - wasm runtime workspace
  #   3. `external_agents/<id>/`       - cached agent binary archive
  #   4. `extensions/index.json`       - surgical per-extension edit
  #                                       via `jq`, atomic tempfile mv
  #
  # The index edit mirrors `zedAgentServersPurge`: precheck file
  # existence, precheck JSON validity, write to a tempfile, atomic
  # `mv` on success, `rm` on failure. We deliberately avoid deleting
  # `index.json` wholesale so other (still-installed) extensions are
  # not disturbed. Running after `linkGeneration` means the desired
  # settings are already on disk by the time we clean up.
  home.activation = {
    zedAgentServersPurge = lib.hm.dag.entryBetween [ "zedSettingsActivation" ] [ "linkGeneration" ] ''
      settings_path=${lib.escapeShellArg zedSettingsPath}
      managed=${lib.escapeShellArg (builtins.toJSON managedAgentServers)}
      jq=${lib.getExe pkgs.jq}

      # First-run on a fresh machine: nothing to purge yet.
      if [[ ! -f "$settings_path" ]]; then
        exit 0
      fi

      # Skip silently if the file is unreadable as JSON (corrupt or empty).
      if ! "$jq" -e . "$settings_path" >/dev/null 2>&1; then
        exit 0
      fi

      tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_path.XXXXXX")"
      if "$jq" --argjson managed "$managed" '
        if has("agent_servers") then
          .agent_servers |= with_entries(select(.key as $k | $managed | index($k)))
        else . end
      ' "$settings_path" > "$tmp"; then
        ${pkgs.coreutils}/bin/mv "$tmp" "$settings_path"
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      fi
    '';

    zedDisabledExtensionsPurge = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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
  };
}
