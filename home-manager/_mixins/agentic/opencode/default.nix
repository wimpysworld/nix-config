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
  aiSopsFile = ../../../../secrets/ai.yaml;
  robotEmoji = builtins.fromJSON "\"\\ud83e\\udd16\"";
  # Use the pre-built binary from numtide's llm-agents.nix flake.
  # This avoids upstream source build issues entirely.
  opencodeUpstreamPackage = inputs.llm-agents.packages.${system}.opencode;
  geminiKeyPath = config.sops.secrets.GEMINI_API_KEY.path;
  communicationRules = config.agentic.communicationRules;
  opencodeTripwireAdapterFile = pkgs.writeTextFile {
    name = "opencode-communication-rules-adapter-source";
    destination = "/share/agent-communication-rules/adapters/opencode.sh";
    executable = true;
    text = builtins.readFile ../hooks/communication-rules/adapters/opencode.sh;
  };
  opencodeTripwireAdapterPath = "${opencodeTripwireAdapterFile}/share/agent-communication-rules/adapters/opencode.sh";
  opencodeTripwireCorrectionPromptFile = pkgs.writeTextFile {
    name = "opencode-communication-rules-correction-prompt.md";
    text = communicationRules.correctionPrompt;
  };
  opencodeTripwirePlugin =
    builtins.replaceStrings
      [
        "@tripwireAdapter@"
        "@tripwireAdapterContract@"
        "@tripwireScanner@"
        "@tripwireRules@"
        "@tripwirePolicy@"
        "@tripwireCorrectionPrompt@"
      ]
      [
        opencodeTripwireAdapterPath
        communicationRules.adapterContractPath
        communicationRules.executable
        communicationRules.rulesPath
        communicationRules.policyFilePath
        "${opencodeTripwireCorrectionPromptFile}"
      ]
      (builtins.readFile ./plugins/communication-rules.ts);
  # Wrap opencode so its process inherits Gemini env vars sourced from sops at
  # invocation time. opencode's loader recognises GEMINI_API_KEY; the
  # underlying @ai-sdk/google SDK reads GOOGLE_GENERATIVE_AI_API_KEY. Export
  # both so the Google provider works regardless of which path opencode
  # follows. The read is non-fatal because opencode is multi-provider and
  # must still launch for non-Google providers when the key is absent.
  opencodePackage = pkgs.symlinkJoin {
    name = "opencode-wrapped-${opencodeUpstreamPackage.version or "unknown"}";
    paths = [ opencodeUpstreamPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode \
        --run '
          if [ -r "${geminiKeyPath}" ]; then
            GEMINI_API_KEY="$(cat "${geminiKeyPath}")"
            export GEMINI_API_KEY
            GOOGLE_GENERATIVE_AI_API_KEY="$GEMINI_API_KEY"
            export GOOGLE_GENERATIVE_AI_API_KEY
          fi
        '
    '';
    inherit (opencodeUpstreamPackage) meta;
    passthru = (opencodeUpstreamPackage.passthru or { }) // {
      unwrapped = opencodeUpstreamPackage;
    };
  };
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceWaylandBridge = import ../fence/wayland-bridge.nix { inherit pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };
  opencodeFencedPackage = pkgs.writeShellApplication {
    name = "opencode-fenced";
    runtimeInputs = [
      fencePackage
    ]
    ++ fenceWaylandBridge.runtimeInputs
    ++ fenceLogging.runtimeInputs;
    text = ''
      ${fenceWaylandBridge.setupShell}

      fence_log_agent="opencode"
      ${fenceLogging.setupShell}

      export OPENCODE_PERMISSION='{"*":"allow"}'
      fence "''${fence_args[@]}" -- "''${fence_env[@]}" ${lib.getExe' opencodePackage "opencode"} "$@"
    '';
  };

  # Import shared MCP server definitions.
in
{
  sops.secrets.GEMINI_API_KEY = {
    sopsFile = aiSopsFile;
    mode = "0400";
  };

  catppuccin.opencode.enable = config.programs.opencode.enable;

  home.packages = lib.optional host.is.linux opencodeFencedPackage;

  xdg.configFile = lib.mkIf (config.programs.opencode.enable && communicationRules.enable) {
    "opencode/plugins/communication-rules.ts".text = opencodeTripwirePlugin;
  };

  programs = {
    bash.shellAliases = lib.mkIf host.is.linux {
      opencode-fenced = lib.getExe opencodeFencedPackage;
    };
    fish.shellAliases = lib.mkIf host.is.linux {
      opencode-fenced = lib.getExe opencodeFencedPackage;
    };
    opencode = {
      enable = true;
      package = opencodePackage;
      settings = {
        # Nix owns the installed OpenCode version, so upstream self-updates are
        # disabled. Updates should flow through the flake inputs instead.
        autoupdate = false;

        # Block session sharing entirely. The default "manual" still allows
        # /share; "disabled" removes it. OpenCode has no usage telemetry per
        # its maintainers, so this is the main privacy control.
        share = "disabled";

        # OpenTelemetry is off by default; set it explicitly.
        experimental = {
          openTelemetry = false;
        };

        # Default to GPT 5.5 via the OpenAI provider with high reasoning effort.
        # The per-model option goes under provider.openai.models so OpenCode
        # forwards `reasoning.effort` on the Responses API call.
        model = "openai/gpt-5.5";
        provider = {
          openai = {
            models = {
              "gpt-5.5" = {
                options = {
                  reasoningEffort = "high";
                };
              };
            };
          };
        };

        # Context compaction - manual control
        # Use /compact slash command when context gets full
        # OpenCode displays token usage in the interface to help monitor
        compaction = {
          auto = false; # Disable automatic compaction
          prune = true; # Keep pruning old tool outputs to save tokens
        };

        # Override built-in /init with custom create-agents-md command
        command = {
          init = {
            description = "Create AGENTS.md ${robotEmoji}";
            agent = "rosey";
            template = builtins.readFile ../assistants/agents/rosey/commands/create-agents-md/prompt.md;
          };
        };
      };
      tui = {
        tui = {
          diff_style = "stacked";
          scroll_acceleration = {
            enabled = true;
          };
        };

        # ------------------------------------------------------------
        # Keybindings - Standard CUA text editor navigation
        # ------------------------------------------------------------
        keybinds = {
          # Core principle: Arrow keys, Home, End, and standard navigation
          # work like a normal text editor. PgUp/PgDn scroll chat history.
          # Full CUA (Common User Access) clipboard support.

          # Application control
          app_exit = "ctrl+d"; # Quit application, unified across all agents on Ctrl+D
          session_interrupt = "escape"; # Interrupt model (keep default)

          # Text input cursor movement - standard arrow keys only
          input_move_up = "up";
          input_move_down = "down";
          input_move_left = "left";
          input_move_right = "right";

          # History navigation - use Ctrl+Up/Down (avoiding Alt conflicts with window manager)
          history_previous = "ctrl+up";
          history_next = "ctrl+down";

          # Home/End - dedicated to line navigation in input
          input_line_home = "home";
          input_line_end = "end";
          input_buffer_home = "ctrl+home"; # Top of input buffer
          input_buffer_end = "ctrl+end"; # Bottom of input buffer

          # Message navigation - PgUp/PgDn for scrolling
          messages_first = "shift+pageup"; # Jump to first message
          messages_last = "shift+pagedown"; # Jump to last message
          messages_page_up = "pageup"; # Scroll up one page
          messages_page_down = "pagedown"; # Scroll down one page
          messages_next = "none"; # Not bound (use PgDn to scroll)
          messages_previous = "none"; # Not bound (use PgUp to scroll)

          # Newline insertion - Shift+Enter (primary) plus alternatives
          input_newline = "shift+return,ctrl+return";

          # Submit on Enter
          input_submit = "return";

          # Selection with Shift+Arrows (standard text editor)
          input_select_up = "shift+up";
          input_select_down = "shift+down";
          input_select_left = "shift+left";
          input_select_right = "shift+right";
          input_select_line_home = "shift+home"; # Select to line start
          input_select_line_end = "shift+end"; # Select to line end
          input_select_buffer_home = "ctrl+shift+home,ctrl+a"; # Select to buffer start (Ctrl+A = CUA "Select All")
          input_select_buffer_end = "ctrl+shift+end"; # Select to buffer end

          # Note: Ctrl+A (Select All in CUA) selects from cursor to buffer start.
          # For true "select all": Press Ctrl+End (go to end) then Ctrl+A (select to start).
          # Most of the time you're already at the end when typing, so Ctrl+A works as expected.

          # Word movement (standard Windows/Linux text editor style)
          input_word_forward = "ctrl+right";
          input_word_backward = "ctrl+left";
          input_select_word_forward = "ctrl+shift+right";
          input_select_word_backward = "ctrl+shift+left";

          # Standard CUA (Common User Access) clipboard
          input_clear = "none"; # No clear binding needed (just select all & delete if needed)
          input_paste = "ctrl+v,shift+insert,ctrl+shift+v"; # Paste - standard CUA + terminal paste
          # Pending https://github.com/anomalyco/opencode/pull/7520
          #input_copy = "ctrl+insert"; # Copy selection (CUA standard)
          #input_cut = "shift+delete"; # Cut selection (CUA standard)
          input_undo = "ctrl+z"; # Undo
          input_redo = "ctrl+shift+z"; # Redo

          # Keyboard-based text copying in OpenCode:
          # 1. Select text with Shift+Arrow keys (or other input_select_* bindings)
          # 2. Press Ctrl+Insert to copy selected text to clipboard (CUA standard)
          # 3. Press Shift+Delete to cut selected text (copy + delete) (CUA standard)
          # 4. Press Ctrl+V or Shift+Insert to paste
          #
          # CUA-standard keybindings (Common User Access from IBM/Windows/Office):
          # - Work reliably across all terminal emulators (not intercepted)
          # - Align with existing input_paste default (Shift+Insert)
          # - Avoid conflicts with terminal native shortcuts (Ctrl+Shift+C/V)
          #
          # Alternative - Mouse-based copying:
          # - SELECT TEXT WITH MOUSE: automatically copied via OSC52
          # - Ctrl+Shift+V pastes (terminal native)
          # - Ctrl+V pastes (CUA standard, configured above)
          # - Shift+Insert pastes (CUA alternative, configured above)

          # Delete operations - standard text editor with CUA
          input_backspace = "backspace";
          input_delete = "delete"; # Plain Delete key only (Shift+Del is for cut in CUA)
          input_delete_word_forward = "ctrl+delete"; # Delete word forward
          input_delete_word_backward = "ctrl+backspace"; # Delete word backward
          input_delete_line = "ctrl+shift+k"; # Delete entire line
        };
      };
    };
    zsh.shellAliases = lib.mkIf host.is.linux {
      opencode-fenced = lib.getExe opencodeFencedPackage;
    };
  };
}
