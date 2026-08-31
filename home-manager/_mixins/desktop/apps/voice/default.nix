{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isHandyHost = host.is.linux && host.is.workstation && noughtyLib.hostHasTag "handy";
  providers = [
    {
      id = "openai";
      label = "OpenAI";
      base_url = "https://api.openai.com/v1";
      allow_base_url_edit = false;
      models_endpoint = "/models";
      supports_structured_output = true;
    }
    {
      id = "zai";
      label = "Z.AI";
      base_url = "https://api.z.ai/api/paas/v4";
      allow_base_url_edit = false;
      models_endpoint = "/models";
      supports_structured_output = true;
    }
    {
      id = "openrouter";
      label = "OpenRouter";
      base_url = "https://openrouter.ai/api/v1";
      allow_base_url_edit = false;
      models_endpoint = "/models";
      supports_structured_output = true;
    }
    {
      id = "anthropic";
      label = "Anthropic";
      base_url = "https://api.anthropic.com/v1";
      allow_base_url_edit = false;
      models_endpoint = "/models";
      supports_structured_output = false;
    }
    {
      id = "groq";
      label = "Groq";
      base_url = "https://api.groq.com/openai/v1";
      allow_base_url_edit = false;
      models_endpoint = "/models";
      supports_structured_output = false;
    }
    {
      id = "cerebras";
      label = "Cerebras";
      base_url = "https://api.cerebras.ai/v1";
      allow_base_url_edit = false;
      models_endpoint = "/models";
      supports_structured_output = true;
    }
    {
      id = "bedrock_mantle";
      label = "AWS Bedrock (Mantle)";
      base_url = "https://bedrock-mantle.us-east-1.api.aws/v1";
      allow_base_url_edit = false;
      models_endpoint = "/models";
      supports_structured_output = true;
    }
    {
      id = "custom";
      label = "Custom";
      base_url = "http://localhost:11434/v1";
      allow_base_url_edit = true;
      models_endpoint = "/models";
      supports_structured_output = false;
    }
  ];
  providerDefaults = lib.listToAttrs (map (provider: lib.nameValuePair provider.id "") providers);
  handySettings = {
    settings_schema_version = 2;
    # Handy has no disabled binding value. An empty binding makes shortcut
    # registration fail, so the compositor owns the transcription shortcut.
    bindings = {
      transcribe = {
        id = "transcribe";
        name = "Transcribe";
        description = "Converts your speech into text.";
        default_binding = "ctrl+space";
        current_binding = "";
      };
      transcribe_with_post_process = {
        id = "transcribe_with_post_process";
        name = "Transcribe with Post-Processing";
        description = "Converts your speech into text and applies AI post-processing.";
        default_binding = "ctrl+shift+space";
        current_binding = "";
      };
      cancel = {
        id = "cancel";
        name = "Cancel";
        description = "Cancels the current recording.";
        default_binding = "escape";
        current_binding = "escape";
      };
    };
    push_to_talk = true;
    audio_feedback = false;
    audio_feedback_volume = 1.0;
    sound_theme = "marimba";
    start_hidden = true;
    autostart_enabled = false;
    update_checks_enabled = false;
    show_whats_new_on_update = false;
    whats_new_last_seen_version = "0.9.6";
    always_on_microphone = false;
    selected_microphone = null;
    selected_channel = null;
    clamshell_microphone = null;
    selected_output_device = null;
    translate_to_english = false;
    selected_language = "en";
    overlay_position = "bottom";
    debug_mode = false;
    log_level = "info";
    custom_words = [ ];
    model_unload_timeout = "min5";
    word_correction_threshold = 0.18;
    history_limit = 5;
    recording_retention_period = "preserve_limit";
    paste_method = "direct";
    clipboard_handling = "dont_modify";
    auto_submit = false;
    auto_submit_key = "enter";
    post_process_enabled = false;
    post_process_provider_id = "openai";
    post_process_providers = providers;
    post_process_api_keys = providerDefaults;
    post_process_models = providerDefaults;
    post_process_prompts = [ ];
    post_process_selected_prompt_id = null;
    mute_while_recording = false;
    append_trailing_space = false;
    app_language = "en";
    theme = "system";
    experimental_enabled = false;
    lazy_stream_close = false;
    keyboard_implementation = "tauri";
    show_tray_icon = true;
    paste_delay_ms = 60;
    paste_delay_after_ms = 60;
    reliable_paste = false;
    typing_tool = "wtype";
    external_script_path = null;
    filler_word_removal_enabled = true;
    custom_filler_words = null;
    transcribe_accelerator = "auto";
    ort_accelerator = "auto";
    transcribe_gpu_device = null;
    extra_recording_buffer_ms = 0;
    vad_enabled = true;
    overlay_style = "live";
  };
  handySettingsStore = pkgs.writeText "handy-settings-store.json" (
    builtins.toJSON {
      settings = handySettings;
    }
  );
  prepareHandySettings = pkgs.writeShellApplication {
    name = "prepare-handy-settings";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      config_home="''${XDG_CONFIG_HOME:-"$HOME/.config"}"
      config_dir="$config_home/com.pais.handy"
      settings_file="$config_dir/settings_store.json"
      dynamic_settings='{"selected_model":"","onboarding_completed":false}'

      mkdir -p "$config_dir"

      if [ -f "$settings_file" ]; then
        if existing_settings="$(
          jq --compact-output --slurp '
            (if length == 1 then .[0] else {} end)
            |
            (if type == "object" and (.settings? | type == "object") then .settings else {} end) as $settings
            | {
                selected_model: (
                  if ($settings.selected_model? | type) == "string"
                  then $settings.selected_model
                  else ""
                  end
                ),
                onboarding_completed: (
                  if ($settings.onboarding_completed? | type) == "boolean"
                  then $settings.onboarding_completed
                  else false
                  end
                )
              }
          ' "$settings_file" 2>/dev/null
        )"; then
          dynamic_settings="$existing_settings"
        fi
      fi

      temporary_file="$(mktemp "$config_dir/.settings_store.json.XXXXXX")"
      trap 'rm -f -- "$temporary_file"' EXIT

      jq --compact-output --argjson dynamic "$dynamic_settings" \
        '.settings += $dynamic' \
        ${handySettingsStore} > "$temporary_file"
      chmod 0600 "$temporary_file"
      mv -T -- "$temporary_file" "$settings_file"
      trap - EXIT
    '';
  };
in
lib.mkIf isHandyHost {
  services.handy = {
    enable = true;
    package = pkgs.handy;
  };

  home.packages = [
    pkgs.handy
    pkgs.wtype
  ];

  systemd.user.services.handy.Service.ExecStartPre = lib.getExe prepareHandySettings;
}
