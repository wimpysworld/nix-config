{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  matrixCfg = config.agentic.moltis.matrix;
  githubCompanionCfg = config.agentic.moltis.githubCompanion;

  isMartin = noughtyLib.isUser [ "martin" ];
  moltisEnabled = isMartin && (host.is.linux || host.is.darwin) && noughtyLib.hostHasTag "moltis";

  username = config.noughty.user.name;
  homeDir = config.home.homeDirectory;
  agentName = host.name;
  isTraya = agentName == "traya";
  mainProvider = if isTraya then "openai-codex" else "gemini";
  mainModelName = if isTraya then "gpt-6-astra" else "gemini-4-argon";
  mainModel = "${mainProvider}::${mainModelName}";
  auxiliaryModel =
    if isTraya then "openai-codex::gpt-6-luna@reasoning-high" else "gemini::gemini-3.8-flash";
  auxiliaryReasoningEffort = if isTraya then "high" else "medium";
  stateDir = "${config.xdg.stateHome}/moltis";
  mcporterConfig = "${config.xdg.configHome}/moltis/mcporter.json";
  mcpServerDefs = import ../mcp/servers.nix { inherit config pkgs; };
  mcpRequiredSecrets = lib.remove "LINEAR_API_KEY" (
    mcpServerDefs.requiredSecretsForConsumers [ "moltis" ]
  );
  linearSecrets = [
    "MOLTIS_LINEAR_CLIENT_ID"
    "MOLTIS_LINEAR_CLIENT_SECRET"
  ];
  mcpExportedSecrets = lib.intersectLists [ "CONTEXT7_API_KEY" ] mcpRequiredSecrets;
  mcpReadySecrets =
    mcpRequiredSecrets
    ++ linearSecrets
    ++ lib.optional (mcpServerDefs.moltisCapabilities ? cloudflare-api) "CLOUDFLARE_API_TOKEN"
    ++ lib.optional (matrixCfg.enable || githubCompanionCfg.enable) "MATRIX_PASSWORD";
  mcpInstructions = ''
    For all MCP operations, use only `mcporter --config "$MCPORTER_CONFIG" ...` through `exec`, with `--no-oauth`.
    Never use native MCP tools or management controls.
    Read `${homeDir}/.moltis/TOOLS.md` for the full transport, capability, and safety rules before MCP work.
  '';
  mcporterPackage = pkgs.callPackage ./linear-token {
    mcporter = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.mcporter;
    clientIdPath = config.sops.secrets.MOLTIS_LINEAR_CLIENT_ID.path;
    clientSecretPath = config.sops.secrets.MOLTIS_LINEAR_CLIENT_SECRET.path;
    cacheDirectory = "${stateDir}/linear-${agentName}";
    configPath = mcporterConfig;
    linearUrl = mcpServerDefs.moltisMcporterServers.linear.url;
  };
  mcpCliMigration = pkgs.callPackage ./mcp-cli-migration { };
  nativeMcpManagementTools = [
    "mcp_list"
    "mcp_add"
    "mcp_remove"
    "mcp_status"
    "mcp_restart"
  ];
  agentDisplayName =
    if agentName == "zannah" then
      "Zannah"
    else if agentName == "traya" then
      "Traya"
    else
      "Skrye";
  scheduleDow =
    if agentName == "zannah" then
      3
    else if agentName == "traya" then
      5
    else
      1;
  scheduleDayName =
    if agentName == "zannah" then
      "Wednesday"
    else if agentName == "traya" then
      "Friday"
    else
      "Monday";

  moltisSopsFile = ../../../../secrets/moltis.yaml;
  matrixSopsFile = ../../../../secrets/matrix.yaml;
  aiSopsFile = ../../../../secrets/ai.yaml;
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  linearSopsFile = ../../../../secrets/linear.yaml;

  # Per-host Gemini TTS voice (`skrye` uses the British commercial voice;
  # `zannah` uses the British concierge voice).
  googleTtsVoice =
    if isTraya then
      "en-gb-tutor-13"
    else if host.name == "zannah" then
      "en-gb-concierge-6"
    else
      "en-gb-commercial-6";
  googleTtsModel = "gemini-3.8-flash-tts";
  googleSttModel = "gemini-3.8-flash";
  ttsShimPort = 13139;
  llamaSwapPort = 8080;
  darwinLlamaCacheRoot = "${stateDir}/llama-models/huggingface";
  llamaRuntime = import ../../../../nixos/_mixins/server/llama-server/runtime.nix { inherit lib; };
  selectedLlamaRuntime = llamaRuntime.mkRuntime {
    acceleration = host.gpu.compute.acceleration or null;
    cacheRoot = if host.is.darwin then darwinLlamaCacheRoot else llamaRuntime.defaultCacheRoot;
    hostVramGiB = host.gpu.compute.vram or 0;
  };
  embeddingModel = selectedLlamaRuntime.selectedRuntimeModels.embedding;
  embeddingDownloads = builtins.filter (
    entry: entry.modelRef == embeddingModel.modelRef
  ) selectedLlamaRuntime.selectedModelDownloads;
  darwinPreseedModelsJson = pkgs.writeText "moltis-llama-models-preseed.json" (
    builtins.toJSON embeddingDownloads
  );
  darwinPreseedModels = pkgs.writeShellApplication {
    name = "moltis-llama-preseed-models";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      jq
      python3Packages.huggingface-hub
    ];
    text = builtins.readFile ../../../../nixos/_mixins/server/llama-server/preseed-models.sh;
  };
  darwinLaunchLlamaServer = pkgs.writeShellApplication {
    name = "moltis-llama-server-launch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.llama-cpp
    ];
    text = ''
      modelPathPattern="$1"
      port="$2"
      shift 2

      snapshotRoot="''${modelPathPattern%/*/*}"
      modelFileName="''${modelPathPattern##*/}"

      mapfile -t modelPathMatches < <(
        find "$snapshotRoot" -mindepth 2 -maxdepth 2 -name "$modelFileName" -print
      )

      if [[ "''${#modelPathMatches[@]}" -ne 1 ]]; then
        printf 'Error: expected one model path for pattern %s, got %s\n' \
          "$modelPathPattern" "''${#modelPathMatches[@]}" >&2
        exit 1
      fi

      modelPath="$(readlink -f "''${modelPathMatches[0]}")"

      exec ${lib.getExe' pkgs.llama-cpp "llama-server"} \
        --port "$port" \
        -m "$modelPath" \
        "$@"
    '';
  };
  darwinLlamaSwapSettings = {
    globalTTL = 0;
    healthCheckTimeout = 500;
    startPort = 10001;
    models.${embeddingModel.publicName} = {
      cmd = ''
        ${lib.getExe darwinLaunchLlamaServer} '${embeddingModel.resolvedPrimaryPathPattern}' ''${PORT} ${lib.escapeShellArgs embeddingModel.runtimeArgs}
      '';
      metadata = {
        inherit (embeddingModel)
          hfRepo
          modelRef
          role
          ;
      };
      name = embeddingModel.publicName;
    };
    groups.embedding = {
      exclusive = false;
      members = [ embeddingModel.publicName ];
      swap = false;
    };
  };
  darwinLlamaSwapConfig = pkgs.writeText "moltis-llama-swap.yaml" (
    builtins.toJSON darwinLlamaSwapSettings
  );
  darwinLlamaSwapService = pkgs.writeShellApplication {
    name = "moltis-llama-swap";
    runtimeInputs = [
      darwinPreseedModels
      pkgs.coreutils
      pkgs.llama-swap
    ];
    text = ''
      export LLAMA_PRESEED_CACHE_ROOT=${lib.escapeShellArg darwinLlamaCacheRoot}
      export LLAMA_PRESEED_MODELS_JSON=${lib.escapeShellArg "${darwinPreseedModelsJson}"}
      moltis-llama-preseed-models
      exec ${lib.getExe pkgs.llama-swap} \
        --listen "127.0.0.1:${toString llamaSwapPort}" \
        --config ${lib.escapeShellArg "${darwinLlamaSwapConfig}"}
    '';
  };
  geminiKeyPath = config.sops.secrets.GEMINI_API_KEY.path;
  ghTokenPath = config.sops.secrets.GH_TOKEN.path;
  gitAuthorEmailPath = config.sops.secrets.GIT_AUTHOR_EMAIL.path;
  sshKeyPath = config.sops.secrets.ssh_key.path;

  # Environment variables the composed `moltis.toml` references, mapped to
  # the sops file each one comes from.
  moltisSecretSopsFiles = {
    TELEGRAM_BOT_TOKEN = moltisSopsFile;
    TELEGRAM_ALLOWED_USERS = moltisSopsFile;
    GH_TOKEN = moltisSopsFile;
    GIT_AUTHOR_EMAIL = moltisSopsFile;
    GEMINI_API_KEY = aiSopsFile;
    CONTEXT7_API_KEY = mcpSopsFile;
  }
  // lib.optionalAttrs (matrixCfg.enable || githubCompanionCfg.enable) {
    MATRIX_PASSWORD = matrixSopsFile;
  };

  secretConfig =
    name:
    if lib.elem name linearSecrets then
      {
        sopsFile = linearSopsFile;
        key = "moltis/${agentName}/${
          if name == "MOLTIS_LINEAR_CLIENT_ID" then "client_id" else "client_secret"
        }";
        mode = "0400";
      }
    else if name == "MATRIX_PASSWORD" then
      {
        sopsFile = matrixSopsFile;
        key = "MATRIX_PASSWORD_${lib.toUpper agentName}";
        mode = "0400";
      }
    else if name == "TELEGRAM_BOT_TOKEN" then
      {
        sopsFile = moltisSopsFile;
        key = "TELEGRAM_BOT_${lib.toUpper agentName}";
      }
    else if name == "TELEGRAM_ALLOWED_USERS" then
      {
        sopsFile = moltisSopsFile;
        key = "TELEGRAM_OPERATOR_IDS";
      }
    else if name == "GH_TOKEN" then
      {
        sopsFile = moltisSopsFile;
        key = "GITHUB_TOKEN_${lib.toUpper agentName}";
        mode = "0400";
      }
    else if name == "GIT_AUTHOR_EMAIL" then
      {
        sopsFile = moltisSopsFile;
        key = "GITHUB_EMAIL_${lib.toUpper agentName}";
        mode = "0400";
      }
    else if name == "GEMINI_API_KEY" then
      {
        sopsFile = aiSopsFile;
        mode = "0400";
      }
    else
      { sopsFile = moltisSecretSopsFiles.${name}; };

  # Plumbing for the composed `moltis.toml`: one entry per environment
  # variable, with its sops source and ready-made placeholder.
  moltisEnvPlumbing = map (
    name:
    {
      inherit name;
    }
    // {
      sopsFile = moltisSecretSopsFiles.${name};
      placeholder = config.sops.placeholder.${name};
    }
  ) (lib.attrNames moltisSecretSopsFiles);

  # PATH entries for the systemd user unit, so it can find user profile tools.
  moltisPath = lib.concatStringsSep ":" (
    [
      "${mcporterPackage}/bin"
      "${homeDir}/.nix-profile/bin"
      "${homeDir}/.local/state/nix/profile/bin"
      "/etc/profiles/per-user/${username}/bin"
      "/run/current-system/sw/bin"
      "/run/wrappers/bin"
      "/nix/var/nix/profiles/default/bin"
    ]
    ++ lib.optionals host.is.darwin [
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ]
  );

  # Fence plumbing for the daemon wrapper: only the fence binary and the
  # logging helper. The shared agent-share, wayland-bridge, git, and
  # chromium setups target interactive TUI agents; a headless daemon needs
  # none of direnv capture, Wayland bridging, git setup, or Chromium.
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };

  # Local OpenAI-compatible `/v1/audio/speech` and `/v1/audio/transcriptions`
  # shim backed by Google's `gemini-3.8-flash-tts` and `gemini-3.8-flash`
  # models and `ffmpeg` transcoding. Moltis' built-in Google Gemini TTS path
  # hardcodes `AudioFormat::Mp3` and returns raw `audio/wav` bytes
  # (`crates/voice/src/tts/google.rs`, tag 20261023.01), whereas `OpenAiTts`
  # preserves `request.output_format` (`AudioFormat::Opus` -> `"opus"` /
  # `audio/ogg`), allowing Moltis to send native Telegram OGG Opus voice notes
  # (`crates/voice/src/tts/openai.rs` and `crates/chat/src/channels/tts.rs`).
  # Inbound voice messages use `WhisperStt` against `/v1/audio/transcriptions`
  # (`crates/voice/src/stt/whisper.rs`).
  moltisTtsShim = pkgs.writeScript "moltis-tts-shim" ''
    #!${lib.getExe pkgs.python3}
    import base64
    from email.parser import BytesParser
    from email.policy import default as email_default_policy
    import http.server
    import json
    import os
    from pathlib import Path
    import re
    import socketserver
    import subprocess
    import sys
    import urllib.error
    import urllib.request

    DEFAULT_MODEL = ${builtins.toJSON googleTtsModel}
    DEFAULT_STT_MODEL = ${builtins.toJSON googleSttModel}
    DEFAULT_VOICE = ${builtins.toJSON googleTtsVoice}
    FFMPEG_BIN = ${builtins.toJSON (lib.getExe pkgs.ffmpeg-headless)}
    GEMINI_KEY_PATH = os.environ.get("MOLTIS_TTS_GEMINI_KEY_PATH", ${builtins.toJSON geminiKeyPath})
    DEFAULT_MATRIX_STATE_PATH = ${builtins.toJSON "${stateDir}/matrix-companion-${agentName}/state.json"}
    MATRIX_STATE_PATH = (
        os.environ.get("MOLTIS_TTS_MATRIX_STATE_PATH")
        or (
            os.path.join(os.environ["MOLTIS_COMPANION_STATE_DIR"], "state.json")
            if os.environ.get("MOLTIS_COMPANION_STATE_DIR")
            else DEFAULT_MATRIX_STATE_PATH
        )
    )
    MARTIN_MATRIX_ID = "@martin:matrix.wimpys.world"
    ASSESSMENT_BADGES = {"👌", "👌🏻", "👍", "👍🏻", "✋", "✋🏻", "🫳", "🫳🏻"}
    VOICE_REQUEST_RE = re.compile(
        r"\b(?:voice|audio|spoken|speak|aloud|tts|read\s+this\s+out|say\s+this|say\s+it)\b",
        re.IGNORECASE,
    )
    VOICE_REFUSAL_RE = re.compile(
        r"\b(?:"
        r"text[- ]only|"
        r"(?:reply|respond)(?:\s+only)?\s+in\s+text|"
        r"no\s+(?:voice|audio|spoken|speech|tts)|"
        r"without\s+(?:voice|audio|spoken|speech|tts)|"
        r"(?:do\s+not|don['’]?t|never)\s+(?:speak|say|read(?:\s+this|\s+it)?\s+out|use\s+(?:voice|audio|tts)|send\s+(?:a\s+)?(?:voice|audio))|"
        r"not\s+(?:aloud|out\s+loud|in\s+voice|with\s+(?:voice|audio))"
        r")\b",
        re.IGNORECASE,
    )
    HOST = os.environ.get("MOLTIS_TTS_SHIM_HOST", "127.0.0.1")
    PORT = int(os.environ.get("MOLTIS_TTS_SHIM_PORT", ${builtins.toJSON (toString ttsShimPort)}))
    SUPPORTED_AUDIO_MIMES = {
        "audio/ogg",
        "audio/wav",
        "audio/mp3",
        "audio/mpeg",
        "audio/aac",
        "audio/flac",
    }


    def resolve_matrix_state_path(state_path=None):
        if state_path:
            return str(state_path)
        env_path = (os.environ.get("MOLTIS_TTS_MATRIX_STATE_PATH") or "").strip()
        if env_path:
            return env_path
        env_dir = (os.environ.get("MOLTIS_COMPANION_STATE_DIR") or "").strip()
        if env_dir:
            return os.path.join(env_dir, "state.json")
        return MATRIX_STATE_PATH


    def _load_recent_matrix_events(state_path=None):
        resolved = Path(resolve_matrix_state_path(state_path)).expanduser()
        candidates = [resolved]
        if resolved.name != "room-events.json":
            candidates.append(resolved.parent / "room-events.json")
        for candidate in candidates:
            if not candidate.is_file():
                continue
            try:
                raw = json.loads(candidate.read_text(encoding="utf-8", errors="replace"))
            except (OSError, ValueError):
                continue
            if not isinstance(raw, dict):
                continue
            room_events = raw.get("room_events") if isinstance(raw.get("room_events"), dict) else raw
            recent = room_events.get("recent_events")
            if isinstance(recent, list) and recent:
                return recent
        return []


    NEW_COMMAND_STRIP_TOKENS = frozenset(
        {
            "skrye",
            "@skrye",
            "traya",
            "@traya",
            "zannah",
            "@zannah",
            "martin",
            "@martin",
        }
    )


    def _is_martin_new_command(body: str) -> bool:
        tokens = [
            tok
            for tok in (body or "").strip().split()
            if not tok.rstrip(":,.;").endswith(":matrix.wimpys.world")
            and tok.rstrip(":,.;").lower() not in NEW_COMMAND_STRIP_TOKENS
        ]
        return len(tokens) == 1 and tokens[0].lower() == "/new"


    def martin_requested_voice(state_path: str | None = None) -> bool:
        recent_events = _load_recent_matrix_events(state_path)
        for ev in reversed(recent_events):
            if not isinstance(ev, dict):
                continue
            sender = str(ev.get("sender") or "").strip()
            if sender != MARTIN_MATRIX_ID and not sender.startswith("@martin:"):
                continue
            content = ev.get("content") if isinstance(ev.get("content"), dict) else {}
            msgtype = str(ev.get("msgtype") or content.get("msgtype") or "m.text").strip()
            if msgtype not in ("m.text", "m.audio"):
                continue
            body = str(ev.get("body") if "body" in ev else content.get("body") or "").strip()
            if not body or ev.get("is_new_command") or _is_martin_new_command(body):
                continue
            if VOICE_REFUSAL_RE.search(body):
                return False
            return bool(VOICE_REQUEST_RE.search(body))
        return False


    def load_api_key():
        env_key = os.environ.get("GEMINI_API_KEY", "").strip()
        if env_key:
            return env_key
        with open(GEMINI_KEY_PATH, "r", encoding="utf-8") as fh:
            return fh.read().strip()


    def synthesize_gemini(api_key, model, voice, text, instructions=None):
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        payload = {
            "contents": [{"parts": [{"text": text}]}],
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                    "voiceConfig": {
                        "prebuiltVoiceConfig": {
                            "voiceName": voice,
                        }
                    }
                },
            },
        }
        if instructions:
            payload["systemInstruction"] = {"parts": [{"text": instructions}]}

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": api_key,
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read().decode("utf-8"))

        inline = (
            body.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [{}])[0]
            .get("inlineData", {})
        )
        audio_b64 = inline.get("data")
        if not audio_b64:
            raise RuntimeError("Gemini TTS response missing inlineData.data")
        return base64.b64decode(audio_b64), inline.get("mimeType", "audio/wav")


    def transcode_audio(raw_bytes, response_format):
        fmt = (response_format or "opus").lower()
        if fmt in ("opus", "ogg"):
            cmd = [
                FFMPEG_BIN,
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                "pipe:0",
                "-c:a",
                "libopus",
                "-b:a",
                "48k",
                "-f",
                "ogg",
                "pipe:1",
            ]
            content_type = "audio/ogg"
        elif fmt == "mp3":
            cmd = [
                FFMPEG_BIN,
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                "pipe:0",
                "-c:a",
                "libmp3lame",
                "-f",
                "mp3",
                "pipe:1",
            ]
            content_type = "audio/mpeg"
        elif fmt == "wav":
            if raw_bytes.startswith(b"RIFF"):
                return raw_bytes, "audio/wav"
            cmd = [
                FFMPEG_BIN,
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                "pipe:0",
                "-f",
                "wav",
                "pipe:1",
            ]
            content_type = "audio/wav"
        elif fmt in ("aac", "m4a"):
            cmd = [
                FFMPEG_BIN,
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                "pipe:0",
                "-c:a",
                "aac",
                "-f",
                "adts",
                "pipe:1",
            ]
            content_type = "audio/aac"
        elif fmt == "pcm":
            cmd = [
                FFMPEG_BIN,
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                "pipe:0",
                "-f",
                "s16le",
                "-acodec",
                "pcm_s16le",
                "pipe:1",
            ]
            content_type = "audio/pcm"
        else:
            cmd = [
                FFMPEG_BIN,
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                "pipe:0",
                "-c:a",
                "libopus",
                "-b:a",
                "48k",
                "-f",
                "ogg",
                "pipe:1",
            ]
            content_type = "audio/ogg"

        proc = subprocess.run(
            cmd,
            input=raw_bytes,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if proc.returncode != 0:
            err = proc.stderr.decode("utf-8", errors="replace").strip()
            raise RuntimeError(f"ffmpeg exited with {proc.returncode}: {err}")
        return proc.stdout, content_type


    def parse_multipart_audio(content_type, raw_body):
        header_bytes = (
            f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n"
        ).encode("latin-1")
        msg = BytesParser(policy=email_default_policy).parsebytes(header_bytes + raw_body)
        if not msg.is_multipart():
            raise ValueError("expected multipart/form-data request")

        file_bytes = None
        file_mime = None
        filename = None
        model = None

        for part in msg.iter_parts():
            name = part.get_param("name", header="content-disposition")
            if name == "file":
                file_bytes = part.get_payload(decode=True)
                file_mime = part.get_content_type()
                filename = part.get_filename() or ""
            elif name == "model":
                payload = part.get_payload(decode=True)
                if payload is not None:
                    model = payload.decode("utf-8", errors="replace").strip()

        if not file_bytes:
            raise ValueError("missing uploaded audio file")
        return file_bytes, file_mime or "", filename or "", model or ""


    def normalize_stt_audio(raw_bytes, part_mime, filename):
        mime = (part_mime or "").split(";", 1)[0].strip().lower()
        alias_map = {
            "audio/opus": "audio/ogg",
            "audio/x-wav": "audio/wav",
            "audio/wave": "audio/wav",
            "audio/mp4": "audio/aac",
            "audio/m4a": "audio/aac",
            "audio/x-m4a": "audio/aac",
        }
        mime = alias_map.get(mime, mime)
        if mime in SUPPORTED_AUDIO_MIMES:
            return raw_bytes, mime

        ext = os.path.splitext(filename.lower())[1]
        ext_map = {
            ".ogg": "audio/ogg",
            ".opus": "audio/ogg",
            ".oga": "audio/ogg",
            ".wav": "audio/wav",
            ".mp3": "audio/mpeg",
            ".aac": "audio/aac",
            ".m4a": "audio/aac",
            ".flac": "audio/flac",
        }
        if ext in ext_map:
            return raw_bytes, ext_map[ext]

        if raw_bytes.startswith(b"OggS"):
            return raw_bytes, "audio/ogg"
        if raw_bytes.startswith(b"RIFF"):
            return raw_bytes, "audio/wav"
        if raw_bytes.startswith(b"fLaC"):
            return raw_bytes, "audio/flac"
        if raw_bytes.startswith(b"ID3") or raw_bytes[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"):
            return raw_bytes, "audio/mpeg"

        return transcode_audio(raw_bytes, "ogg")


    def transcribe_gemini(api_key, model, audio_bytes, mime_type):
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        b64_audio = base64.b64encode(audio_bytes).decode("ascii")
        payload = {
            "contents": [
                {
                    "parts": [
                        {"inlineData": {"mimeType": mime_type, "data": b64_audio}},
                        {
                            "text": "Transcribe this audio verbatim. Return only the spoken words, with no commentary or formatting."
                        },
                    ]
                }
            ]
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": api_key,
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read().decode("utf-8"))

        parts = (
            body.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [])
        )
        transcript = "".join(
            p.get("text", "")
            for p in parts
            if isinstance(p, dict) and not p.get("thought")
        ).strip()
        return transcript


    class ReusableTCPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
        allow_reuse_address = True
        daemon_threads = True


    class TtsHandler(http.server.BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            return

        def _send_json(self, status, payload):
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _handle_speech(self):
            try:
                length = int(self.headers.get("Content-Length", "0"))
                raw_body = self.rfile.read(length) if length > 0 else b"{}"
                data = json.loads(raw_body.decode("utf-8"))
            except Exception as exc:
                self._send_json(400, {"error": {"message": f"invalid JSON: {exc}"}})
                return

            input_text = data.get("input") or ""
            if not isinstance(input_text, str) or not input_text.strip():
                self._send_json(400, {"error": {"message": "missing input text"}})
                return

            stripped_text = input_text.strip()
            fmt = str(data.get("response_format") or data.get("format") or "opus").strip().lower()
            if stripped_text in ASSESSMENT_BADGES or (fmt == "ogg" and len(stripped_text) <= 16):
                self._send_json(
                    400,
                    {"error": {"message": "ogg TTS rejected for short assessment badge"}},
                )
                return

            if fmt == "ogg" and not martin_requested_voice():
                self._send_json(
                    400,
                    {"error": {"message": "ogg TTS rejected: Martin did not request audio/voice in Matrix"}},
                )
                return

            req_model = data.get("model") or ""
            model = req_model if isinstance(req_model, str) and req_model.startswith("gemini-") else DEFAULT_MODEL
            req_voice = data.get("voice") or ""
            voice = req_voice if isinstance(req_voice, str) and req_voice.startswith("en-") else DEFAULT_VOICE
            response_format = fmt or "opus"
            instructions = data.get("instructions")

            try:
                api_key = load_api_key()
                raw_audio, _ = synthesize_gemini(api_key, model, voice, input_text, instructions)
                out_bytes, content_type = transcode_audio(raw_audio, response_format)
            except urllib.error.HTTPError as exc:
                err_body = exc.read().decode("utf-8", errors="replace")
                sys.stderr.write(f"moltis-tts-shim upstream HTTP {exc.code}: {err_body}\n")
                self._send_json(502, {"error": {"message": f"Gemini TTS HTTP {exc.code}"}})
                return
            except Exception as exc:
                sys.stderr.write(f"moltis-tts-shim error: {exc}\n")
                self._send_json(500, {"error": {"message": str(exc)}})
                return

            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(out_bytes)))
            self.end_headers()
            self.wfile.write(out_bytes)

        def _handle_transcriptions(self):
            content_type = self.headers.get("Content-Type", "")
            if not content_type.lower().startswith("multipart/form-data"):
                self._send_json(400, {"error": {"message": "expected multipart/form-data"}})
                return

            try:
                length = int(self.headers.get("Content-Length", "0"))
                raw_body = self.rfile.read(length) if length > 0 else b""
                file_bytes, part_mime, filename, req_model = parse_multipart_audio(
                    content_type, raw_body
                )
            except Exception as exc:
                self._send_json(400, {"error": {"message": f"invalid multipart request: {exc}"}})
                return

            model = (
                req_model
                if isinstance(req_model, str) and req_model.startswith("gemini-")
                else DEFAULT_STT_MODEL
            )

            try:
                api_key = load_api_key()
                audio_bytes, mime_type = normalize_stt_audio(file_bytes, part_mime, filename)
                transcript = transcribe_gemini(api_key, model, audio_bytes, mime_type)
            except urllib.error.HTTPError as exc:
                err_body = exc.read().decode("utf-8", errors="replace")
                sys.stderr.write(f"moltis-tts-shim STT upstream HTTP {exc.code}: {err_body}\n")
                self._send_json(502, {"error": {"message": f"Gemini STT HTTP {exc.code}"}})
                return
            except Exception as exc:
                sys.stderr.write(f"moltis-tts-shim STT error: {exc}\n")
                self._send_json(500, {"error": {"message": str(exc)}})
                return

            self._send_json(200, {"text": transcript})

        def do_POST(self):
            if self.path in ("/v1/audio/speech", "/audio/speech"):
                self._handle_speech()
            elif self.path in ("/v1/audio/transcriptions", "/audio/transcriptions"):
                self._handle_transcriptions()
            else:
                self._send_json(404, {"error": {"message": "not found"}})


    if __name__ == "__main__":
        with ReusableTCPServer((HOST, PORT), TtsHandler) as httpd:
            httpd.serve_forever()
  '';

  moltisTelegramVoice = pkgs.writeShellApplication {
    name = "moltis-telegram-voice";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      if [[ $# -eq 0 ]]; then
        echo "Usage: moltis-telegram-voice <text> | --body-file <path>" >&2
        exit 1
      fi

      case "$1" in
        -h | --help)
          echo "Usage: moltis-telegram-voice <text> | --body-file <path>"
          exit 0
          ;;
        --body-file)
          if [[ $# -lt 2 || ! -r "$2" ]]; then
            echo "moltis-telegram-voice: --body-file requires a readable file path" >&2
            exit 1
          fi
          text="$(cat "$2")"
          ;;
        -*)
          echo "moltis-telegram-voice: unknown option: $1" >&2
          echo "Usage: moltis-telegram-voice <text> | --body-file <path>" >&2
          exit 2
          ;;
        *)
          text="$*"
          ;;
      esac

      if [[ -z "''${text//[[:space:]]/}" ]]; then
        echo "moltis-telegram-voice: text must not be empty" >&2
        exit 1
      fi

      bot_token="''${TELEGRAM_BOT_TOKEN:-}"
      if [[ -z "$bot_token" && -r "${config.sops.secrets.TELEGRAM_BOT_TOKEN.path}" ]]; then
        bot_token="$(tr -d '\r\n' < "${config.sops.secrets.TELEGRAM_BOT_TOKEN.path}")"
      fi
      if [[ -z "$bot_token" ]]; then
        echo "moltis-telegram-voice: missing TELEGRAM_BOT_TOKEN" >&2
        exit 1
      fi

      chat_id="''${TELEGRAM_ALLOWED_USERS:-}"
      if [[ -z "$chat_id" && -r "${config.sops.secrets.TELEGRAM_ALLOWED_USERS.path}" ]]; then
        chat_id="$(tr -d '\r\n' < "${config.sops.secrets.TELEGRAM_ALLOWED_USERS.path}")"
      fi
      if [[ -z "$chat_id" ]]; then
        echo "moltis-telegram-voice: missing TELEGRAM_ALLOWED_USERS" >&2
        exit 1
      fi

      tmp_ogg="$(mktemp --suffix=.ogg)"
      trap 'rm -f "$tmp_ogg"' EXIT

      payload="$(jq -n \
        --arg input "$text" \
        --arg voice "${googleTtsVoice}" \
        --arg model "${googleTtsModel}" \
        '{model: $model, input: $input, voice: $voice, response_format: "opus"}')"

      curl -fsSL \
        -X POST "http://127.0.0.1:${toString ttsShimPort}/v1/audio/speech" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -o "$tmp_ogg"

      response="$(curl -fsSL \
        -X POST "https://api.telegram.org/bot''${bot_token}/sendVoice" \
        -F "chat_id=''${chat_id}" \
        -F "voice=@''${tmp_ogg};type=audio/ogg")"

      printf '%s\n' "$response" | jq -c '{ok: .ok, message_id: .result.message_id, chat_id: .result.chat.id}'
    '';
  };

  moltisMatrixCompanion = pkgs.callPackage ./matrix-companion {
    inherit
      agentName
      agentDisplayName
      mainModel
      ;
    selfUserId = matrixCfg.userId or "@${agentName}:matrix.wimpys.world";
    roomId = matrixCfg.roomId or "!the-cauldron:matrix.wimpys.world";
    homeserverUrl = "https://matrix.wimpys.world";
    passwordPath = config.sops.secrets.MATRIX_PASSWORD.path;
    dataDir = "${homeDir}/.moltis";
    stateDir = "${stateDir}/matrix-companion-${agentName}";
    rpcUrl = "https://127.0.0.1:13131/api/rpc";
  };

  moltisGithubCompanion = pkgs.callPackage ./github-companion {
    inherit
      agentName
      agentDisplayName
      mainModel
      scheduleDow
      scheduleDayName
      ;
    selfUserId = matrixCfg.userId or "@${agentName}:matrix.wimpys.world";
    roomId = matrixCfg.roomId or "!the-cauldron:matrix.wimpys.world";
    homeserverUrl = "https://matrix.wimpys.world";
    passwordPath = config.sops.secrets.MATRIX_PASSWORD.path;
    telegramBotTokenPath = config.sops.secrets.TELEGRAM_BOT_TOKEN.path;
    telegramAllowedUsersPath = config.sops.secrets.TELEGRAM_ALLOWED_USERS.path;
    dataDir = "${homeDir}/.moltis";
    stateDir = "${stateDir}/github-companion-${agentName}";
    rpcUrl = "https://127.0.0.1:13131/api/rpc";
  };

  moltisMatrixCouncilHook = pkgs.writeScript "moltis-matrix-council-hook" ''
    #!${lib.getExe pkgs.python3}
    import os
    from pathlib import Path
    import sys

    _NIX_COMPANION_DIR = "${./matrix-companion}"
    for _cand in (
        os.environ.get("MOLTIS_MATRIX_COMPANION_DIR") or "",
        _NIX_COMPANION_DIR,
        str(Path(__file__).resolve().parent / "matrix-companion"),
        str(Path.cwd() / "home-manager/_mixins/agentic/moltis/matrix-companion"),
        str(Path.cwd()),
    ):
        if _cand and Path(_cand, "companion.py").is_file():
            sys.path.insert(0, _cand)
            break
    else:
        sys.path.insert(0, _NIX_COMPANION_DIR)
    import companion

    MARKER = companion.COUNCIL_CONTEXT_MARKER
    ASSESSMENT_SESSION_PREFIX = companion.ASSESSMENT_SESSION_PREFIX
    AGENT_NAME = ${builtins.toJSON agentName}
    AGENT_DISPLAY_NAME = ${builtins.toJSON agentDisplayName}
    SELF_USER_ID = ${builtins.toJSON (matrixCfg.userId or "@${agentName}:matrix.wimpys.world")}
    ROOM_ID = ${builtins.toJSON (matrixCfg.roomId or "!the-cauldron:matrix.wimpys.world")}
    DEFAULT_STATE_DIR = ${builtins.toJSON "${stateDir}/matrix-companion-${agentName}"}
    MARTIN_ID = companion.MARTIN_ID
    BOT_IDS = companion.BOT_IDS
    ALLOWLIST_USER_IDS = companion.ALLOWLIST_USER_IDS
    MAX_BOT_TURNS = companion.MAX_BOT_TURNS
    MAX_UNMENTIONED_MESSAGES = companion.MAX_UNMENTIONED_MESSAGES
    MAX_UNMENTIONED_CHARS = companion.MAX_UNMENTIONED_CHARS
    MAX_REACTION_TARGETS = companion.MAX_REACTION_TARGETS
    ENCODED_COMPONENT_BYTES = companion.ENCODED_COMPONENT_BYTES
    MAX_STATE_FILE_BYTES = companion.MAX_RESPONSE_BYTES
    STATE_FILENAME = companion.STATE_FILENAME
    COMPANION_STATE_FILENAME = companion.COMPANION_STATE_FILENAME
    ROOM_EVENTS_FILENAME = companion.ROOM_EVENTS_FILENAME
    ACTIVE_TURN_FILENAME = companion.ACTIVE_TURN_FILENAME
    ACTIVE_TURN_LOCK_FILENAME = companion.ACTIVE_TURN_LOCK_FILENAME

    now_ms = companion.now_ms
    safe_int = companion._safe_int
    check_private = companion.check_private
    open_private_directory = companion.open_private_directory
    read_json_in_dir = companion.read_json_in_dir
    atomic_write_json_in_dir = companion._atomic_write_active_turn_in_dir
    read_state_json = companion._read_state_json_file
    normalize_ts = companion.normalize_ts
    extract_text_content = companion.extract_text_content
    strip_audio_message_suffix = companion.strip_audio_message_suffix
    extract_record_sender = companion.extract_record_sender
    encoded_key_components = companion.encoded_key_components
    extract_latest_user_turn = companion.extract_latest_user_turn
    classify_tool_phase = companion.classify_tool_phase
    extract_tool_name = companion.extract_tool_name
    update_active_turn_file = companion.update_active_turn_file
    read_workspace_file = companion.read_workspace_file
    restore_private_persona = companion.restore_private_persona
    sender_matches = companion._sender_matches
    format_reactions_summary = companion.format_reactions_summary
    is_new_command_text = companion.is_new_command_message
    is_martin_sender = companion._is_martin_sender
    is_bot_sender = companion._is_bot_sender
    is_conversational_room_message = companion.is_conversational_room_message
    compute_bot_turns_since_martin = companion.compute_bot_turns_since_martin


    def emit_continue():
        sys.stdout.write('{"action":"continue"}\n')
        sys.stdout.flush()


    def resolve_state_dir() -> Path:
        env_dir = (os.environ.get("MOLTIS_COMPANION_STATE_DIR") or "").strip()
        if env_dir:
            return Path(env_dir).expanduser()
        return Path(DEFAULT_STATE_DIR).expanduser()


    def resolve_session_generation(data_dir: Path, state_dir: Path) -> tuple[str, int]:
        return companion.resolve_hook_session_generation(
            data_dir=data_dir,
            state_dir=state_dir,
            agent_name=AGENT_NAME,
            room_id=ROOM_ID,
        )


    def history_paths(data_dir: Path, session_key: str) -> list[Path]:
        return companion.history_paths(
            data_dir=data_dir,
            session_key=session_key,
            agent_name=AGENT_NAME,
            room_id=ROOM_ID,
        )


    def load_session_history_records(data_dir: Path, session_key: str) -> list[dict]:
        return companion.load_session_history_records(
            data_dir=data_dir,
            session_key=session_key,
            agent_name=AGENT_NAME,
            room_id=ROOM_ID,
        )


    def is_in_session_history(event: dict, history_records: list[dict], cutoff_ms: int) -> bool:
        return companion.is_in_session_history(
            event=event,
            history_records=history_records,
            cutoff_ms=cutoff_ms,
            self_user_id=SELF_USER_ID,
        )


    def build_room_context_block(
        state_dir: Path,
        active_session_key: str,
        cutoff_ms: int,
        history_records: list[dict],
    ) -> tuple[str, int]:
        return companion.build_room_context_block(
            state_dir=state_dir,
            active_session_key=active_session_key,
            cutoff_ms=cutoff_ms,
            history_records=history_records,
            self_user_id=SELF_USER_ID,
        )


    def build_council_section(
        state_dir: Path,
        active_session_key: str,
        cutoff_ms: int,
        history_records: list[dict],
    ) -> str:
        return companion.build_council_section(
            state_dir=state_dir,
            active_session_key=active_session_key,
            cutoff_ms=cutoff_ms,
            history_records=history_records,
            self_user_id=SELF_USER_ID,
            room_id=ROOM_ID,
        )


    def main():
        companion.run_council_hook_cli(
            agent_name=AGENT_NAME,
            agent_display_name=AGENT_DISPLAY_NAME,
            self_user_id=SELF_USER_ID,
            room_id=ROOM_ID,
            default_state_dir=DEFAULT_STATE_DIR,
        )


    if __name__ == "__main__":
        main()
  '';

  moltisInFenceLauncher = pkgs.writeShellApplication {
    name = "moltis-in-fence";
    runtimeInputs = [
      (pkgs.writeShellScriptBin "dcg" "exit 0")
      moltisTelegramVoice
      mcporterPackage
      pkgs.coreutils
      pkgs.ffmpeg-headless
      pkgs.gh
      pkgs.git
      pkgs.python3
      pkgs.sqlite
    ]
    ++ lib.optional matrixCfg.enable moltisMatrixCompanion
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.systemd ];
    text = ''
      export MCPORTER_CONFIG=${lib.escapeShellArg mcporterConfig}
      unset LINEAR_API_KEY
      ${lib.concatMapStringsSep "\n" (name: ''
        ${name}="$(< ${lib.escapeShellArg config.sops.secrets.${name}.path})"
        export ${name}
      '') mcpExportedSecrets}
      export MOLTIS_DATA_DIR=${lib.escapeShellArg "${homeDir}/.moltis"}
      ${lib.getExe mcpCliMigration} "$MOLTIS_DATA_DIR"

      export GH_TOKEN
      GH_TOKEN="$(< "${ghTokenPath}")"
      export GIT_AUTHOR_NAME=${lib.escapeShellArg agentDisplayName}
      export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
      export GIT_AUTHOR_EMAIL
      GIT_AUTHOR_EMAIL="$(< "${gitAuthorEmailPath}")"
      export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

      export GIT_CONFIG_COUNT=5
      export GIT_CONFIG_KEY_0="commit.gpgSign"
      export GIT_CONFIG_VALUE_0="false"
      export GIT_CONFIG_KEY_1="tag.gpgSign"
      export GIT_CONFIG_VALUE_1="false"
      export GIT_CONFIG_KEY_2="credential.https://github.com.helper"
      export GIT_CONFIG_VALUE_2="!${lib.getExe pkgs.gh} auth git-credential"
      export GIT_CONFIG_KEY_3="url.https://github.com/.insteadOf"
      export GIT_CONFIG_VALUE_3="git@github.com:"
      export GIT_CONFIG_KEY_4="url.https://github.com/.insteadOf"
      export GIT_CONFIG_VALUE_4="ssh://git@github.com/"

      mkdir -p "$HOME/.moltis"
      # Wait up to 60s for the pre-seeded GGUF snapshot and local llama-swap
      # server before Moltis runs its one-time startup memory sync.
      ready=false
      deadline=$((SECONDS + ${"$"}{MOLTIS_EMBEDDING_READY_TIMEOUT_SECS:-60}))
      while (( SECONDS < deadline )); do
        if python3 -c 'import glob, json, os, sys, urllib.request; pattern, url, model = sys.argv[1:4]; ready = any(os.access(p, os.R_OK) for p in glob.glob(pattern)) and any(isinstance(m, dict) and m.get("id") == model for m in json.load(urllib.request.urlopen(url, timeout=1)).get("data", [])); sys.exit(0 if ready else 1)' \
          "${embeddingModel.resolvedPrimaryPathPattern}" \
          "http://127.0.0.1:${toString llamaSwapPort}/v1/models" \
          "${embeddingModel.publicName}" 2>/dev/null; then
          ready=true
          break
        fi
        sleep 0.5
      done
      if [[ $ready != true ]]; then
        echo "moltis-in-fence: timed out waiting for the embedding model" >&2
        exit 1
      fi
      if [[ -f "$MOLTIS_DATA_DIR/memory.db" ]]; then
        has_chunks="$(sqlite3 "$MOLTIS_DATA_DIR/memory.db" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'chunks';" 2>/dev/null || echo 0)"
        if [[ "$has_chunks" == "1" ]]; then
          sqlite3 "$MOLTIS_DATA_DIR/memory.db" "DELETE FROM files WHERE path IN (SELECT path FROM chunks WHERE model != '${embeddingModel.publicName}' OR embedding IS NULL); DELETE FROM chunks WHERE model != '${embeddingModel.publicName}' OR embedding IS NULL; DELETE FROM files WHERE size > 0 AND NOT EXISTS (SELECT 1 FROM chunks WHERE chunks.path = files.path); INSERT INTO chunks_fts(chunks_fts) VALUES ('rebuild'); DELETE FROM embedding_cache WHERE model != '${embeddingModel.publicName}';"
        fi
      fi
      python3 -c 'import glob, json, os, pathlib, sys; root = sys.argv[1]; is_empty = lambda l: isinstance(d := json.loads(l), dict) and d.get("role") == "assistant" and not str(d.get("content") or "").strip() and not d.get("tool_calls") and not str(d.get("reasoning") or "").strip(); [(pathlib.Path(p + ".tmp").write_text("".join(kept), encoding="utf-8"), os.replace(p + ".tmp", p)) for p in glob.glob(os.path.join(root, "sessions", "v1", "**", "history.jsonl"), recursive=True) if (lines := pathlib.Path(p).read_text(encoding="utf-8").splitlines(True)) and len(kept := [l for l in lines if not is_empty(l)]) != len(lines)]' "$MOLTIS_DATA_DIR" 2>/dev/null || true
      printf '["dcg-guard"]\n' > "$HOME/.moltis/disabled_hooks.json"
      touch "$HOME/.moltis/.onboarded"
      ${lib.optionalString host.is.linux ''
        ${moltisTtsShim} &
        ${lib.optionalString matrixCfg.enable ''
          ${lib.getExe moltisMatrixCompanion} &
        ''}
        ${lib.optionalString githubCompanionCfg.enable ''
          ${lib.getExe moltisGithubCompanion} &
        ''}
        exec ${lib.getExe pkgs.moltis} "$@"
      ''}
      ${lib.optionalString host.is.darwin ''
        children=()
        cleanup() {
          trap - EXIT INT TERM
          if (( ''${#children[@]} )); then
            kill "''${children[@]}" 2>/dev/null || true
            wait "''${children[@]}" 2>/dev/null || true
          fi
        }
        trap 'cleanup' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        ${moltisTtsShim} &
        children+=("$!")
        ${lib.optionalString matrixCfg.enable ''
          ${lib.getExe moltisMatrixCompanion} &
          children+=("$!")
        ''}
        ${lib.optionalString githubCompanionCfg.enable ''
          ${lib.getExe moltisGithubCompanion} &
          children+=("$!")
        ''}
        ${lib.getExe pkgs.moltis} "$@" &
        children+=("$!")
        wait -n || true
        cleanup
        exit 1
      ''}
    '';
  };

  moltisFencedPackage = pkgs.writeShellApplication {
    name = "moltis-fenced";
    runtimeInputs = [
      fencePackage
    ]
    ++ fenceLogging.runtimeInputs;
    text = ''
      fence_args=()
      fence_env=()

      fence_log_agent="moltis"
      ${fenceLogging.setupShell}

      for _ in {1..20}; do
        [[ -r "${
          config.sops.templates."moltis.toml".path
        }" && -r "${geminiKeyPath}" && -r "${ghTokenPath}" && -r "${gitAuthorEmailPath}" && -e "${sshKeyPath}" ${
          lib.concatMapStringsSep " " (
            name: "&& -r ${lib.escapeShellArg config.sops.secrets.${name}.path}"
          ) mcpReadySecrets
        } ]] && break
        sleep 0.5
      done
      if [[ ! -r "${
        config.sops.templates."moltis.toml".path
      }" || ! -r "${geminiKeyPath}" || ! -r "${ghTokenPath}" || ! -r "${gitAuthorEmailPath}" || ! -e "${sshKeyPath}" ${
        lib.concatMapStringsSep " " (
          name: "|| ! -r ${lib.escapeShellArg config.sops.secrets.${name}.path}"
        ) mcpReadySecrets
      } ]]; then
        echo "moltis-fenced: timed out waiting for sops-nix secrets" >&2
        exit 1
      fi

      # The rendered `[env]` table supplies internal config substitutions.
      # `moltis-in-fence` exports credentials for child processes and starts
      # the local Gemini TTS shim in the same Fence sandbox and network
      # namespace before replacing the shell
      # with `moltis`, so the gateway stays the foreground daemon and satisfies
      # the unit's `Type = "simple"` contract. `fence-direnv-exec` restores the
      # unit's launch directory ($HOME) after Fence starts in `$fence_empty_cwd`.
      cd -- "$fence_empty_cwd"
      exec fence "''${fence_args[@]}" -- "''${fence_env[@]}" "''${fence_direnv[@]}" ${lib.getExe moltisInFenceLauncher} "$@"
    '';
  };
in
{
  options.agentic.moltis = {
    toolsContext = lib.mkOption {
      type = lib.types.submodule {
        options = {
          homeDirectory = lib.mkOption { type = lib.types.str; };
          system = lib.mkOption { type = lib.types.str; };
          platform = lib.mkOption {
            type = lib.types.enum [
              "darwin"
              "linux"
            ];
          };
          provider = lib.mkOption { type = lib.types.str; };
          mainModel = lib.mkOption { type = lib.types.str; };
          auxiliaryModel = lib.mkOption { type = lib.types.str; };
          mcpServers = lib.mkOption { type = lib.types.listOf lib.types.str; };
          mcporterConfig = lib.mkOption { type = lib.types.str; };
          mcpInstructions = lib.mkOption { type = lib.types.str; };
          nativeMcpManagementTools = lib.mkOption { type = lib.types.listOf lib.types.str; };
          stateDirectory = lib.mkOption { type = lib.types.str; };
          ttsModel = lib.mkOption { type = lib.types.str; };
          ttsVoice = lib.mkOption { type = lib.types.str; };
          sttModel = lib.mkOption { type = lib.types.str; };
          gitName = lib.mkOption { type = lib.types.str; };
        };
      };
      readOnly = true;
      internal = true;
      description = "Public runtime facts for the composed Moltis TOOLS.md.";
    };
    matrix = {
      enable = lib.mkEnableOption "the private Matrix room channel" // {
        default =
          moltisEnabled
          && noughtyLib.isHost [
            "skrye"
            "zannah"
            "traya"
          ];
      };
      userId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "@${agentName}:matrix.wimpys.world";
        description = "Provisioned Matrix user ID on matrix.wimpys.world.";
      };
      roomId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "!the-cauldron:matrix.wimpys.world";
        description = "Provisioned unencrypted Matrix room ID. Room aliases are not accepted.";
      };
    };

    githubCompanion = {
      enable = lib.mkEnableOption "the Moltis GitHub notification and security companion" // {
        default =
          moltisEnabled
          && noughtyLib.isHost [
            "skrye"
            "zannah"
            "traya"
          ];
      };
    };

    envPlumbing = lib.mkOption {
      type =
        with lib.types;
        listOf (
          attrsOf (oneOf [
            str
            path
          ])
        );
      readOnly = true;
      internal = true;
      default = moltisEnvPlumbing;
      description = ''
        Environment variables for the composed Moltis configuration, each with
        its sops file and placeholder.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Moltis settings before sops placeholder substitution.";
    };

    renderedConfig = lib.mkOption {
      type = with lib.types; path;
      readOnly = true;
      description = ''
        Rendered `moltis.toml` for the child service to symlink into the
        writable Moltis config directory. The sops template substitutes the
        placeholder markers at render time, so the path is the only safe
        consumer: the generated file on any store path still holds markers.
      '';
    };
  };

  config = lib.mkIf moltisEnabled (
    let
      # The `[env]` table supplies internal config substitutions from sops
      # template values. It does not export variables to child processes.
      envBlock = lib.listToAttrs (
        lib.map (entry: lib.nameValuePair entry.name entry.placeholder) config.agentic.moltis.envPlumbing
      );
      restartToken = builtins.hashString "sha256" (
        builtins.toJSON {
          template = toString config.sops.templates."moltis.toml".file;
          launcher = toString moltisFencedPackage;
          mcporter = config.xdg.configFile."moltis/mcporter.json".text;
          heartbeat = config.agentic.assistants.moltis.heartbeatHash;
          embedding = embeddingModel;
          secrets = lib.genAttrs (lib.attrNames moltisSecretSopsFiles ++ linearSecrets) (
            name:
            let
              secret = config.sops.secrets.${name};
            in
            {
              source = "${secret.sopsFile}";
              inherit (secret) key;
            }
          );
        }
      );
    in
    {
      assertions =
        lib.optional host.is.linux {
          assertion = noughtyLib.hostHasTag "inference";
          message = "Moltis on Linux requires the host inference tag so llama-swap serves local embeddings.";
        }
        ++ lib.optional host.is.darwin {
          assertion = config.agentic.assistants.requiresSecrets;
          message = "Moltis on Darwin requires the synchronous refreshSopsNix activation step.";
        }
        ++ lib.optionals matrixCfg.enable [
          {
            assertion =
              matrixCfg.userId != null
              && builtins.stringLength matrixCfg.userId <= 255
              && builtins.match "@[a-z0-9._=/-]+:matrix\\.wimpys\\.world" matrixCfg.userId != null;
            message = "agentic.moltis.matrix.userId must be a provisioned Matrix user ID on matrix.wimpys.world when Matrix is enabled.";
          }
          {
            assertion =
              matrixCfg.roomId != null
              && builtins.stringLength matrixCfg.roomId <= 255
              && builtins.match "![^[:space:]]+" matrixCfg.roomId != null;
            message = "agentic.moltis.matrix.roomId must be a provisioned Matrix room ID (!opaque or !opaque:server), not an alias, when Matrix is enabled.";
          }
        ];

      home.packages = [
        pkgs.moltis
        moltisFencedPackage
        moltisTelegramVoice
      ];

      home.shellAliases.moltis-log =
        if host.is.darwin then
          "tail -F ${stateDir}/daemon.stdout.log ${stateDir}/daemon.stderr.log"
        else
          "journalctl --user -u moltis.service";

      home.activation.restartMoltis = lib.mkIf host.is.darwin (
        lib.hm.dag.entryAfter [ "refreshSopsNix" "assistantOwnedFiles" "setupLaunchAgents" ] ''
          restartMoltis() (
            set -e
            umask 077
            stateDir=${lib.escapeShellArg stateDir}
            marker="$stateDir/activation-token"
            if [[ -L "$stateDir" || -L "$marker" || ( -e "$marker" && ! -f "$marker" ) ]]; then
              echo "Moltis: refusing an unsafe activation marker path." >&2
              exit 1
            fi
            if [[ -f "$marker" && "$(< "$marker")" == ${lib.escapeShellArg restartToken} ]]; then
              exit 0
            fi
            domain="gui/$(${pkgs.coreutils}/bin/id -u)"
            if ! /bin/launchctl print "$domain" >/dev/null 2>&1; then
              echo "Moltis: no GUI login domain. Log in and run Home Manager activation again." >&2
              exit 1
            fi
            if ! /bin/launchctl kickstart -k "$domain/org.moltis.gateway"; then
              echo "Moltis: restart failed. The change token remains pending for the next activation." >&2
              exit 1
            fi
            tmp="$(${pkgs.coreutils}/bin/mktemp "$stateDir/.activation-token.XXXXXX")"
            trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
            printf '%s\n' ${lib.escapeShellArg restartToken} > "$tmp"
            ${pkgs.coreutils}/bin/mv -T "$tmp" "$marker"
          )
          run restartMoltis
          unset -f restartMoltis
        ''
      );

      xdg.stateFile."moltis/.keep" = lib.mkIf host.is.darwin { text = ""; };
      launchd.agents = lib.mkIf host.is.darwin {
        llama-swap = {
          enable = true;
          config = {
            Label = "org.moltis.llama-swap";
            ProgramArguments = [ "${darwinLlamaSwapService}/bin/moltis-llama-swap" ];
            EnvironmentVariables = {
              HOME = homeDir;
              PATH = moltisPath;
            };
            WorkingDirectory = homeDir;
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 30;
            StandardOutPath = "${stateDir}/llama-swap.stdout.log";
            StandardErrorPath = "${stateDir}/llama-swap.stderr.log";
          };
        };
        moltis = {
          enable = true;
          config = {
            Label = "org.moltis.gateway";
            ProgramArguments = [ "${moltisFencedPackage}/bin/moltis-fenced" ];
            EnvironmentVariables = {
              HOME = homeDir;
              PATH = moltisPath;
            };
            WorkingDirectory = homeDir;
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 30;
            StandardOutPath = "${stateDir}/daemon.stdout.log";
            StandardErrorPath = "${stateDir}/daemon.stderr.log";
          };
        };
      };

      systemd.user.services.moltis = lib.mkIf host.is.linux {
        # Start only after sops-nix creates the rendered `moltis.toml` symlink.
        Unit = {
          Description = "Moltis - secure persistent personal agent server";
          X-Restart-Triggers = [ restartToken ];
          After = [
            "sops-nix.service"
          ];
          Wants = [
            "sops-nix.service"
          ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${moltisFencedPackage}/bin/moltis-fenced";
          # Only PATH. The rendered `[env]` table already holds real secrets
          # at sops render time; moltis resolves `${VAR}` placeholders
          # against the process env first, then `[env]`.
          Environment = [ "PATH=${moltisPath}" ];
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };

      sops.secrets = lib.genAttrs (lib.attrNames moltisSecretSopsFiles ++ linearSecrets) secretConfig;
      xdg.configFile."moltis/mcporter.json".text = builtins.toJSON {
        imports = [ ];
        mcpServers = mcpServerDefs.moltisMcporterServers // {
          linear = {
            command = lib.getExe mcporterPackage.linearServer;
            lifecycle = "ephemeral";
          };
        };
      };

      agentic.moltis.toolsContext = {
        homeDirectory = homeDir;
        system = pkgs.stdenv.hostPlatform.system;
        platform = if host.is.darwin then "darwin" else "linux";
        provider = mainProvider;
        inherit mainModel auxiliaryModel;
        mcpServers = lib.attrNames mcpServerDefs.moltisCapabilities;
        inherit mcporterConfig mcpInstructions nativeMcpManagementTools;
        stateDirectory = stateDir;
        ttsModel = googleTtsModel;
        ttsVoice = googleTtsVoice;
        sttModel = googleSttModel;
        gitName = agentDisplayName;
      };
      agentic.moltis.renderedConfig = config.sops.templates."moltis.toml".path;

      sops.templates."moltis.toml" = {
        file = (pkgs.formats.toml { }).generate "moltis.toml" config.agentic.moltis.settings;
        path = "${config.xdg.configHome}/moltis/moltis.toml";
      };
      agentic.moltis.settings = {
        # Pin the gateway server address. `ServerConfig::default().port`
        # is 0, and a port of 0 on disk makes `initialize_config()`
        # generate a random port and write it back to the config file it
        # loaded, which against this layout means writing through the
        # sops-rendered symlink on every restart (crates/config/src/
        # schema/system.rs and crates/config/src/loader/config_io.rs,
        # tag 20260913.02). A non-zero port on loopback prevents both.
        server = {
          port = 13131;
          bind = "127.0.0.1";
        };

        identity = {
          name = agentName;
        };

        user = {
          name = "Martin";
          timezone = "Europe/London";
          write_mode = "off";
        };

        auxiliary = {
          compaction = auxiliaryModel;
          title_generation = auxiliaryModel;
          vision = auxiliaryModel;
        };

        chat.compaction.mode = "structured";

        skills.enable_self_improvement = false;

        tools = {
          policy.deny = [ "mcp_*" ];
          agent_timeout_secs = 3600;
          agent_max_iterations = 100;
          agent_max_auto_continues = 0;
          exec = {
            default_timeout_secs = 300;
            max_timeout_secs = 1800;
            approval_mode = "never";
            sandbox.mode = "off";
          };
          fs = {
            workspace_root = homeDir;
            track_reads = true;
            must_read_before_write = true;
          };
        };

        memory = {
          provider = "custom";
          base_url = "http://127.0.0.1:${toString llamaSwapPort}/v1";
          model = embeddingModel.publicName;
        };

        heartbeat = {
          enabled = !config.agentic.moltis.githubCompanion.enable;
          every = "120m";
          model = mainModel;
          sandbox_enabled = false;
          deliver = true;
          channel = "moltis";
          to = "\${TELEGRAM_ALLOWED_USERS}";
        };

        # Moltis resolves `${VAR}` placeholders against the process
        # environment, and the config loader's second pass treats the
        # `[env]` table as an overrides map (crates/config/src/loader.rs,
        # tag 20260913.02). Placeholders here come from `envPlumbing`,
        # so no literal secret value ever enters a store path.
        env = envBlock // {
          MCPORTER_CONFIG = mcporterConfig;
        };

        mcp.servers = { };

        agents = {
          # Preset lane mapping. `coordinator` is the default spawn preset.
          # Every lane pins `reasoning_effort` explicitly. Model ids use
          # Moltis' `provider::model` namespace separator
          # (crates/providers/src/model_id.rs).
          default_preset = "coordinator";
          presets =
            lib.mapAttrs
              (
                _: preset:
                preset
                // {
                  tools = (preset.tools or { }) // {
                    deny = lib.unique ((preset.tools.deny or [ ]) ++ nativeMcpManagementTools);
                  };
                  system_prompt_suffix = lib.concatStringsSep "\n\n" (
                    lib.optional ((preset.system_prompt_suffix or "") != "") preset.system_prompt_suffix
                    ++ [ mcpInstructions ]
                  );
                }
              )
              (
                (import ./builtin-presets.nix)
                // {
                  coordinator = {
                    model = mainModel;
                    reasoning_effort = "medium";
                    delegate_only = false;
                  };
                  auxiliary = {
                    model = auxiliaryModel;
                    reasoning_effort = auxiliaryReasoningEffort;
                  };
                  compression = {
                    model = auxiliaryModel;
                    reasoning_effort = auxiliaryReasoningEffort;
                  };
                  review = {
                    model = mainModel;
                    reasoning_effort = "medium";
                  };
                }
              );
        };

        models = {
          gemini-4-argon.context_window = 1000000;
          gpt-6-astra.context_window = 384000;
          gpt-6-luna.context_window = 384000;
        };

        # No inline `api_key`: the provider reads `GEMINI_API_KEY` from
        # Moltis' internal `[env]` configuration.
        providers = {
          gemini = {
            enabled = !isTraya;
            models = [
              "gemini-4-argon"
              "gemini-3.8-flash"
            ];
          };
        }
        // lib.optionalAttrs isTraya {
          offered = [ "openai-codex" ];
          openai-codex = {
            enabled = true;
            models = [
              "gpt-6-astra"
              "gpt-6-luna"
            ];
            fetch_models = false;
          };
        };

        voice = {
          tts = {
            enabled = true;
            provider = "openai";
            # Route TTS through the local OpenAI-compatible Gemini shim inside
            # `moltis-fenced`. `OpenAiTts::is_configured()` is true whenever
            # `base_url` differs from `https://api.openai.com/v1`, so no
            # `api_key` is needed and `migrate_voice_keys_to_key_store()`
            # never rewrites `moltis.toml` (`crates/voice/src/tts/openai.rs`
            # and `crates/gateway/src/voice/mod.rs`, tag 20261023.01).
            openai = {
              enabled = true;
              base_url = "http://127.0.0.1:${toString ttsShimPort}/v1";
              voice = googleTtsVoice;
              model = googleTtsModel;
            };
          };
          stt = {
            enabled = true;
            provider = "whisper";
            # `WhisperStt::is_configured()` is true whenever `base_url`
            # differs from `https://api.openai.com/v1`
            # (`crates/voice/src/stt/whisper.rs`, tag 20261023.01).
            whisper = {
              base_url = "http://127.0.0.1:${toString ttsShimPort}/v1";
              model = googleSttModel;
            };
          };
        };

        channels = {
          offered = [ "telegram" ] ++ lib.optional matrixCfg.enable "matrix";
          telegram.moltis = {
            # BotFather token arrives through `[env]`; Moltis applies
            # `${VAR}` substitution to the whole raw config text, not
            # per-field, so `token` expands at load time
            # (crates/config/src/loader.rs, tag 20260913.02).
            token = "\${TELEGRAM_BOT_TOKEN}";
            dm_policy = "allowlist";
            # Whole-file substitution also covers array elements, so
            # the allowlist can reference a secret env var. One value,
            # exactly one username or user id: upstream does not split
            # comma-joined values here.
            allowlist = [ "\${TELEGRAM_ALLOWED_USERS}" ];
            operators = [ "\${TELEGRAM_ALLOWED_USERS}" ];
            group_policy = "disabled";
            stream_mode = "edit_in_place";
            stream_min_initial_chars = 30;
            edit_throttle_ms = 1000;
            reply_to_message = true;
            otp_self_approval = false;
            model = mainModelName;
            model_provider = mainProvider;
          };
        }
        // lib.optionalAttrs matrixCfg.enable {
          matrix."matrix-${agentName}" = {
            homeserver = "https://matrix.wimpys.world";
            auth_mode = "password";
            password = "\${MATRIX_PASSWORD}";
            user_id = matrixCfg.userId;
            device_id = "MOLTIS_${lib.toUpper agentName}";
            model = mainModelName;
            model_provider = mainProvider;
            ownership_mode = "user_managed";
            dm_policy = "allowlist";
            otp_self_approval = false;
            room_policy = "allowlist";
            room_allowlist = [ matrixCfg.roomId ];
            mention_mode = "mention";
            auto_join = "allowlist";
            reply_to_message = false;
            user_allowlist = [
              "@martin:matrix.wimpys.world"
              "@skrye:matrix.wimpys.world"
              "@zannah:matrix.wimpys.world"
              "@traya:matrix.wimpys.world"
            ];
            operators = [ "@martin:matrix.wimpys.world" ];
            private_instance = true;
            stream_mode = "off";
          };
        };

        hooks.hooks = lib.optional matrixCfg.enable {
          name = "matrix-council-context";
          command = "${moltisMatrixCouncilHook}";
          events = [
            "BeforeLLMCall"
            "BeforeToolCall"
          ];
          timeout = 10;
        };
      };
    }
  );
}
