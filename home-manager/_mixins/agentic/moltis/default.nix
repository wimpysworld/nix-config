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

  isMartin = noughtyLib.isUser [ "martin" ];
  moltisEnabled = isMartin && (host.is.linux || host.is.darwin) && noughtyLib.hostHasTag "moltis";

  username = config.noughty.user.name;
  homeDir = config.home.homeDirectory;
  agentName = if host.name == "momin" then "traya" else host.name;
  isTraya = agentName == "traya";
  mainProvider = if isTraya then "openai-codex" else "gemini";
  mainModelName = if isTraya then "gpt-6-astra" else "gemini-4-argon";
  mainModel = "${mainProvider}::${mainModelName}";
  auxiliaryModel =
    if isTraya then "openai-codex::gpt-6-luna@reasoning-high" else "gemini::gemini-3.8-flash";
  auxiliaryReasoningEffort = if isTraya then "high" else "medium";
  stateDir = "${config.xdg.stateHome}/moltis";
  mcporterConfig = "${config.xdg.configHome}/moltis/mcporter.json";
  mcpInstructions = ''
    For all MCP operations, use only `mcporter --config "$MCPORTER_CONFIG" ...` through `exec`, with `--no-oauth`.
    Never use native MCP tools or management controls.
    Read `${homeDir}/.moltis/TOOLS.md` for the full transport, capability, and safety rules before MCP work.
  '';
  mcporterPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.mcporter;
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

  moltisSopsFile = ../../../../secrets/moltis.yaml;
  aiSopsFile = ../../../../secrets/ai.yaml;
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  linearSopsFile = ../../../../secrets/linear.yaml;
  # Same work-host split that `mcp/default.nix` uses for `LINEAR_API_KEY`:
  # one `key` attribute per identity in the same sops file.
  isWorkHost = lib.elem "cg" (host.tags or [ ]);

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
    LINEAR_API_KEY = linearSopsFile;
  };

  secretConfig =
    name:
    if name == "LINEAR_API_KEY" then
      {
        sopsFile = linearSopsFile;
        key = if isWorkHost then "chainguard" else "wimpysworld";
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

            req_model = data.get("model") or ""
            model = req_model if isinstance(req_model, str) and req_model.startswith("gemini-") else DEFAULT_MODEL
            req_voice = data.get("voice") or ""
            voice = req_voice if isinstance(req_voice, str) and req_voice.startswith("en-") else DEFAULT_VOICE
            response_format = data.get("response_format") or "opus"
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

  moltisInFenceLauncher = pkgs.writeShellApplication {
    name = "moltis-in-fence";
    runtimeInputs = [
      (pkgs.writeShellScriptBin "dcg" "exit 0")
      moltisTelegramVoice
      mcporterPackage
      pkgs.ffmpeg-headless
      pkgs.gh
      pkgs.git
      pkgs.python3
      pkgs.sqlite
    ];
    text = ''
      export MCPORTER_CONFIG=${lib.escapeShellArg mcporterConfig}
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
      printf '["dcg-guard"]\n' > "$HOME/.moltis/disabled_hooks.json"
      touch "$HOME/.moltis/.onboarded"
      ${lib.optionalString host.is.linux ''
        ${moltisTtsShim} &
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
        }" && -r "${geminiKeyPath}" && -r "${ghTokenPath}" && -r "${gitAuthorEmailPath}" && -e "${sshKeyPath}" ]] && break
        sleep 0.5
      done
      if [[ ! -r "${
        config.sops.templates."moltis.toml".path
      }" || ! -r "${geminiKeyPath}" || ! -r "${ghTokenPath}" || ! -r "${gitAuthorEmailPath}" || ! -e "${sshKeyPath}" ]]; then
        echo "moltis-fenced: timed out waiting for sops-nix secrets" >&2
        exit 1
      fi

      # The rendered `[env]` table already carries the real secret values at
      # sops render time, so unlike `opencode-fenced` no key-read prologue is
      # needed here. `moltis-in-fence` starts the local Gemini TTS shim in the
      # same Fence sandbox and network namespace before replacing the shell
      # with `moltis`, so the gateway stays the foreground daemon and satisfies
      # the unit's `Type = "simple"` contract. The `fence_direnv` launcher is
      # inert here: the unit runs at $HOME, away from any project `.envrc`.
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
      # Import the shared MCP server definitions the same way
      # `mcp/default.nix` does; never re-derive the renderer.
      mcpServerDefs = import ../mcp/servers.nix { inherit config pkgs; };

      # The `[env]` table: one entry per plumbing variable, values replaced
      # with the rendered secret at sops template render time. Moltis makes
      # `[env]` variables part of its process environment, so the literal
      # `${NAME}` placeholders in rendered MCP image headers resolve from it
      # (loader second pass treats `[env]` as an overrides map).
      envBlock = lib.listToAttrs (
        lib.map (entry: lib.nameValuePair entry.name entry.placeholder) config.agentic.moltis.envPlumbing
      );
    in
    {
      assertions = lib.optional host.is.darwin {
        assertion = config.agentic.assistants.requiresSecrets;
        message = "Moltis on Darwin requires the synchronous refreshSopsNix activation step.";
      };

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
        let
          restartToken = builtins.hashString "sha256" (
            builtins.toJSON {
              template = toString config.sops.templates."moltis.toml".file;
              launcher = toString moltisFencedPackage;
              mcporter = config.xdg.configFile."moltis/mcporter.json".text;
              secrets = lib.genAttrs (lib.attrNames moltisSecretSopsFiles) (
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
      launchd.agents.moltis = lib.mkIf host.is.darwin {
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

      systemd.user.services.moltis = lib.mkIf host.is.linux {
        # Start only after sops-nix creates the rendered `moltis.toml` symlink.
        Unit = {
          Description = "Moltis - secure persistent personal agent server";
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

      sops.secrets = lib.genAttrs (lib.attrNames moltisSecretSopsFiles) secretConfig;
      xdg.configFile."moltis/mcporter.json".text = builtins.toJSON {
        imports = [ ];
        mcpServers = mcpServerDefs.moltisMcporterServers;
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
          base_url = "https://generativelanguage.googleapis.com/v1beta/openai";
          model = "gemini-embedding-2";
          api_key = "\${GEMINI_API_KEY}";
        };

        heartbeat = {
          enabled = true;
          every = "30m";
          model = auxiliaryModel;
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

        # No inline `api_key`: Moltis does not expand `${VAR}` placeholders
        # inside provider `api_key` values, so `GEMINI_API_KEY` comes from
        # the process environment swept in by `[env]`.
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
          offered = [ "telegram" ];
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
        };
      };
    }
  );
}
