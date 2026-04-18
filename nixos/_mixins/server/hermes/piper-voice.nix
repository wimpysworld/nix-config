{ config, lib, noughtyLib, pkgs, ... }:
let
  hermesVoiceDir = "${config.services.hermes-agent.stateDir}/.hermes/piper-voices";
  username = config.noughty.user.name;
  voiceHash = "5512791644e2148e4be301d4c7fc2a4bf51a5057"; # Piper voices commit hash for reproducibility
in
lib.mkIf (noughtyLib.hostHasTag "hermes") {
  # Systemd service to download Piper voice model at boot
  systemd.services.piper-voice-setup = lib.mkMerge [
    {
      description = "Download Piper TTS voice models from Hugging Face";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      partOf = [ "hermes-agent.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Group = root;
        StandardOutput = "journal";
        StandardError = "journal";
        
        # Download script with commit hash pinning for reproducibility
        ExecStart = "${pkgs.writeShellApplication {
          name = "download-piper-voice";
          runtimeInputs = [ pkgs.wget pkgs.coreutils ];
          
          text = ''
            set -euo pipefail

            VOICE_DIR="${hermesVoiceDir}"
            mkdir -p "$VOICE_DIR"

            echo "Downloading southern_english_female-high voice (commit: ${voiceHash:0:7})..."

            # Download using immutable commit hash for reproducibility
            wget -qO "$VOICE_DIR/en_GB-southern_english_female-high.onnx" \
              "https://huggingface.co/rhasspy/piper-voices/resolve/${voiceHash}/en/en_GB/southern_english_female/high/en_GB-southern_english_female-high.onnx"

            # Download the model config file
            wget -qO "$VOICE_DIR/en_GB-southern_english_female-high.onnx.json" \
              "https://huggingface.co/rhasspy/piper-voices/resolve/${voiceHash}/en/en_GB/southern_english_female/high/en_GB-southern_english_female-high.onnx.json"

            # Verify download integrity
            if [[ ! -f "$VOICE_DIR/en_GB-southern_english_female-high.onnx" ]]; then
              echo "✗ Failed to download voice model (.onnx)" >&2
              exit 1
            fi

            if [[ ! -f "$VOICE_DIR/en_GB-southern_english_female-high.onnx.json" ]]; then
              echo "✗ Failed to download model config (.json)" >&2
              exit 1
            fi

            # Verify file size (high quality voice is ~30MB)
            MODEL_SIZE=$(stat -c%s "$VOICE_DIR/en_GB-southern_english_female-high.onnx" 2>/dev/null || stat -f%z "$VOICE_DIR/en_GB-southern_english_female-high.onnx")
            if (( MODEL_SIZE < 25*1024*1024 )); then
              echo "✗ Voice model file size too small: ${MODEL_SIZE} bytes (expected ~30MB)" >&2
              exit 1
            fi

            echo "✓ Voice model downloaded successfully"
            ls -lh "$VOICE_DIR/"*.onnx "$VOICE_DIR/"*.json

            # Ensure proper ownership for hermes user
            chown ${username}:${config.users.groups.hermes.name} "$VOICE_DIR"/*
            chmod 0640 "$VOICE_DIR"/*
          '';
        }}/bin/download-piper-voice";
      };
    }

    # Skip download if voice already exists (idempotency)
    {
      unitConfig.ConditionPathExists = "!${hermesVoiceDir}/en_GB-southern_english_female-high.onnx";
    }
  ];

  # Ensure hermes-agent starts after piper-voice-setup completes
  systemd.services.hermes-agent = {
    after = [ "piper-voice-setup.service" ];
    requires = [ "piper-voice-setup.service" ];
    restartMode = "on-failure";
  };
}
