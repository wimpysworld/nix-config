{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
  # https://github.com/numtide/llm-agents.nix
  claudePackage =
    if host.is.linux then
      inputs.llm-agents.packages.${system}.claude-code
    else if host.is.darwin then
      pkgs.unstable.claude-code
    else
      pkgs.claude-code;
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };

  # ACP adapter that lets Zed drive Claude Code over the Agent Client
  # Protocol. The binary is `claude-agent-acp`, sourced from the same
  # llm-agents flake input so the version is pinned alongside claude-code.
  claudeAgentAcpPackage = inputs.llm-agents.packages.${system}.claude-agent-acp;

  claudeFencedPackage = pkgs.writeShellApplication {
    name = "claude-fenced";
    runtimeInputs = [
      fencePackage
      pkgs.ncurses
    ];
    text = ''
      if [ -z "''${CCSTATUSLINE_WIDTH:-}" ]; then
        width="$(tput cols 2>/dev/null || true)"
        case "$width" in
          "" | *[!0-9]*)
            ;;
          *)
            export CCSTATUSLINE_WIDTH="$width"
            ;;
        esac
      fi

      exec fence -- ${lib.getExe' claudePackageWithLsp "claude"} --dangerously-skip-permissions "$@"
    '';
  };

  # Import shared MCP server definitions
  mcpServerDefs = import ../mcp/servers.nix { inherit config pkgs; };

  # Per-server allow entries derived from `mcpServerDefs.claudeServers`. Each
  # `mcp__<servername>` rule matches every tool exposed by that server, so
  # adding a server in `mcp/servers.nix` auto-extends this list with no edits
  # here. The previous bare `"mcp__*"` rule was a no-op because Claude Code's
  # permission matcher does not accept that wildcard form; valid shapes are
  # `mcp__<servername>`, `mcp__<servername>__*`, or
  # `mcp__<servername>__<toolname>`.
  mcpAllow = map (name: "mcp__${name}") (lib.attrNames mcpServerDefs.claudeServers);

  # Replacement for Claude Code's built-in `@` file picker. Pipes `fd` into
  # `fzf --filter` so queries get real fuzzy scoring and untracked files,
  # gitignored files, and symlinked trees all participate. Wired into
  # `settings.fileSuggestion` below.
  fileSuggestionCommand = pkgs.callPackage ./file-suggestion { };

  # Patch ccstatusline to accept null values for the five_hour and seven_day
  # fields in the Anthropic usage API response. The API returns null for these
  # fields when no usage data is available, but ccstatusline's Zod schema uses
  # `.optional()` rather than `.nullish()` for the outer object wrapper.
  # `.optional()` permits `undefined` but rejects `null`, so safeParse fails
  # and the session-usage and weekly-usage widgets render "[Parse Error]"
  # indefinitely. Replacing `.optional()` with `.nullish()` on the outer object
  # accepts both undefined and null, matching the actual API contract.
  #
  # v2.2.0 expanded the schema to include resets_at alongside utilization,
  # so the match pattern covers the full three-line block for each field.
  ccstatuslinePatched = inputs.llm-agents.packages.${system}.ccstatusline.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.perl ];
    postInstall = (old.postInstall or "") + ''
      # Patch five_hour and seven_day outer object wrappers from .optional()
      # to .nullish() so that the Zod schema accepts null (not just undefined)
      # when the Anthropic API returns null for those fields. The v2.2.0
      # schema spans multiple lines; perl -0pe slurps the whole file so
      # [^}]+ matches across newlines inside the object literal.
      perl -i -0pe \
        's/(five_hour: exports_external\.object\(\{[^}]+\}\))\.optional\(\),/$1.nullish(),/s;
         s/(seven_day: exports_external\.object\(\{[^}]+\}\))\.optional\(\),/$1.nullish(),/s' \
        "$out/bin/ccstatusline"
    '';
  });

  inherit (config.claude-code) lspServers;

  # Wrap Claude Code with LSP plugin support when language modules contribute
  # LSP server configurations. Sets ENABLE_LSP_TOOL=1 and passes --plugin-dir
  # pointing to the generated .lsp.json location. When no LSP servers are
  # configured, the unwrapped package is used unchanged.
  claudePackageWithLsp =
    if lspServers != { } then
      pkgs.symlinkJoin {
        name = "claude-code-with-lsp";
        paths = [ claudePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude \
            --set ENABLE_LSP_TOOL 1 \
            --add-flags "--plugin-dir ${config.home.homeDirectory}/.claude/plugins/nix-lsp"
        '';
      }
    else
      claudePackage;
in
{
  options.claude-code.lspServers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
    default = { };
    description = "LSP server configurations contributed by language modules, merged into .lsp.json";
  };

  config = {
    home = {
      file = lib.mkIf (lspServers != { }) {
        ".claude/plugins/nix-lsp/.lsp.json".text = builtins.toJSON lspServers;
      };
      packages = [
        inputs.llm-agents.packages.${system}.ccusage
        ccstatuslinePatched
        claudeAgentAcpPackage
      ]
      ++ lib.optional host.is.linux claudeFencedPackage;
      # Skip Claude Code's bundled ripgrep in favour of the system binary on
      # PATH. The bundled `rg` crashes on 16 KB-page kernels (Apple Silicon,
      # some Linux configs), silently emptying the file picker. Using the Nix
      # ripgrep is harmless on every other host and avoids the failure mode
      # entirely. See CLAUDE-FUZZY-FINDER-IS-DOGSHIT.md and upstream #11307.
      sessionVariables = {
        USE_BUILTIN_RIPGREP = "0";
      };
    };

    # Declarative configuration for ccstatusline.
    # Settings are written to ~/.config/ccstatusline/settings.json, which is the
    # default path the tool reads on startup. The status line command is injected
    # into Claude Code's settings.json by the claude-code Home Manager module.
    xdg.configFile."ccstatusline/settings.json".text = builtins.toJSON {
      version = 3;
      # Plain values required: builtins.toJSON serialises lib.mkDefault wrappers
      # verbatim as attribute sets, which fails ccstatusline's Zod schema validation.
      flexMode = "full-minus-40";
      compactThreshold = 60;
      colorLevel = 2;
      defaultPadding = " ";
      defaultSeparator = "|";
      inheritSeparatorColors = false;
      globalBold = false;
      powerline = {
        enabled = false;
        separators = [ "\uE0B0" ];
        separatorInvertBackground = [ false ];
        startCaps = [ ];
        endCaps = [ ];
        autoAlign = false;
      };
      lines = [
        [
          # Line 1: model identity, session information, and block timing.
          # Explicit separator widgets are intentionally absent: defaultSeparator
          # already inserts a "|" between every adjacent widget pair automatically.
          # Adding both causes triple separators (defaultSep + widget + defaultSep).
          {
            id = "1";
            type = "model";
            color = "cyan";
          }
          {
            id = "3";
            type = "session-clock";
            color = "yellow";
          }
          {
            id = "5";
            type = "session-usage";
            color = "brightBlue";
          }
          {
            id = "7";
            type = "session-cost";
            color = "green";
          }
          # Block Reset Timer uses type "reset-timer" per the widget manifest
          # (BlockResetTimerWidget is registered under that key, not "block-reset-timer").
          {
            id = "10";
            type = "block-timer";
            color = "yellow";
          }
          {
            id = "12";
            type = "reset-timer";
            color = "brightYellow";
          }
          # Weekly widgets follow the block timers on the same line. When no
          # weekly usage data is available they return null and are skipped by the
          # renderer, so no blank line is ever reserved.
          {
            id = "14";
            type = "weekly-usage";
            color = "brightBlue";
          }
          {
            id = "16";
            type = "weekly-reset-timer";
            color = "brightCyan";
          }
          {
            id = "9";
            type = "session-name";
            color = "magenta";
          }
        ]
        [
          # Line 3: token counts and context bar.
          {
            id = "17";
            type = "tokens-input";
            color = "brightBlack";
          }
          {
            id = "19";
            type = "tokens-output";
            color = "brightBlack";
          }
          {
            id = "21";
            type = "tokens-cached";
            color = "brightBlack";
          }
          {
            id = "23";
            type = "tokens-total";
            color = "white";
          }
          {
            id = "25";
            type = "context-bar";
            color = "brightGreen";
          }
        ]
      ];
    };
    programs = {
      bash.shellAliases = lib.mkIf host.is.linux {
        claude-fenced = lib.getExe claudeFencedPackage;
      };
      claude-code = {
        enable = true;
        package = claudePackageWithLsp;
        # Use Home Manager's native MCP support with shared server definitions
        mcpServers = mcpServerDefs.claudeServers;
        settings = {
          # MCP servers are selected declaratively through Home Manager. Project
          # MCP servers remain opt-in instead of being silently trusted.
          enableAllProjectMcpServers = false;

          # Wire ccstatusline into Claude Code's status bar. The module writes
          # this value to ~/.claude/settings.json under the "statusLine" key,
          # which Claude Code reads on startup to invoke the formatter.
          statusLine = {
            type = "command";
            command = lib.getExe ccstatuslinePatched;
            padding = 0;
          };

          # Replace the built-in `@` file picker with `fd | fzf --filter`.
          # The built-in matcher is a bespoke subsequence scorer capped at 15
          # results and gated on `git ls-files`, so untracked or word-fragment
          # queries fail. Claude Code invokes this command per keystroke with
          # JSON `{"query": "..."}` on stdin. See ./file-suggestion for the
          # script body and CLAUDE-FUZZY-FINDER-IS-DOGSHIT.md for context.
          fileSuggestion = {
            type = "command";
            command = lib.getExe fileSuggestionCommand;
          };
        }
        // lib.optionalAttrs host.is.linux {
          skipDangerousModePermissionPrompt = true;
        };
      };
      fish.shellAliases = lib.mkIf host.is.linux {
        claude-fenced = lib.getExe claudeFencedPackage;
      };
      zsh.shellAliases = lib.mkIf host.is.linux {
        claude-fenced = lib.getExe claudeFencedPackage;
      };
    };
  };
}
