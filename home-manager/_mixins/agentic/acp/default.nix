{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
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

  zedSettingsPath = "${config.xdg.configHome}/zed/settings.json";
in
lib.mkIf config.programs.zed-editor.enable {
  programs.zed-editor = {
    userKeymaps = acpKeymaps;
    userSettings = {
      agent_servers = acpAgentServers;
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
  home.activation.zedAgentServersPurge =
    lib.hm.dag.entryBetween [ "zedSettingsActivation" ] [ "linkGeneration" ]
      ''
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
}
