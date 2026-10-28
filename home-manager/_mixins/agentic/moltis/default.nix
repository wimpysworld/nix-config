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
  moltisEnabled = isMartin && host.is.linux && noughtyLib.hostHasTag "moltis";

  username = config.noughty.user.name;
  homeDir = config.home.homeDirectory;

  herdrSopsFile = ../../../../secrets/herdr.yaml;
  aiSopsFile = ../../../../secrets/ai.yaml;
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  linearSopsFile = ../../../../secrets/linear.yaml;
  # Same work-host split that `mcp/default.nix` uses for `LINEAR_API_KEY`:
  # one `key` attribute per identity in the same sops file.
  isWorkHost = lib.elem "cg" (host.tags or [ ]);

  # Per-host Gemini TTS voice (`skrye` uses the assistant voice; `zannah`
  # uses the commercial voice).
  googleTtsVoice = if host.name == "zannah" then "en-gb-commercial-6" else "en-gb-assistant-9";
  googleTtsModel = "gemini-3.8-flash-tts";
  ttsShimPort = 13132;
  geminiKeyPath = config.sops.secrets.GEMINI_API_KEY.path;

  # Environment variables the composed `moltis.toml` references, mapped to
  # the sops file each one comes from.
  moltisSecretSopsFiles = {
    TELEGRAM_BOT_TOKEN = herdrSopsFile;
    TELEGRAM_HOME_CHANNEL = herdrSopsFile;
    TELEGRAM_ALLOWED_USERS = herdrSopsFile;
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
        sopsFile = herdrSopsFile;
        key = "TELEGRAM_BOT_${lib.toUpper host.name}";
      }
    else if name == "TELEGRAM_HOME_CHANNEL" then
      {
        sopsFile = herdrSopsFile;
        key = "TELEGRAM_CHAT_ID_${lib.toUpper host.name}";
      }
    else if name == "TELEGRAM_ALLOWED_USERS" then
      {
        sopsFile = herdrSopsFile;
        key = "TELEGRAM_OPERATOR_IDS";
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
  moltisPath = lib.concatStringsSep ":" [
    "${homeDir}/.nix-profile/bin"
    "${homeDir}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${username}/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  # Fence plumbing for the daemon wrapper: only the fence binary and the
  # logging helper. The shared agent-share, wayland-bridge, git, and
  # chromium setups target interactive TUI agents; a headless daemon needs
  # none of direnv capture, Wayland bridging, git setup, or Chromium.
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };

  # Local OpenAI-compatible `/v1/audio/speech` shim backed by Google's
  # `gemini-3.8-flash-tts` model and `ffmpeg` transcoding. Moltis' built-in
  # Google Gemini TTS path hardcodes `AudioFormat::Mp3` and returns raw
  # `audio/wav` bytes (`crates/voice/src/tts/google.rs`, tag 20261023.01),
  # whereas `OpenAiTts` preserves `request.output_format` (`AudioFormat::Opus` ->
  # `"opus"` / `audio/ogg`), allowing Moltis to send native Telegram OGG Opus
  # voice notes (`crates/voice/src/tts/openai.rs` and
  # `crates/chat/src/channels/tts.rs`).
  moltisTtsShim = pkgs.writeScript "moltis-tts-shim" ''
    #!${lib.getExe pkgs.python3}
    import base64
    import ctypes
    import http.server
    import json
    import os
    import signal
    import socketserver
    import subprocess
    import sys
    import urllib.error
    import urllib.request

    DEFAULT_MODEL = ${builtins.toJSON googleTtsModel}
    DEFAULT_VOICE = ${builtins.toJSON googleTtsVoice}
    FFMPEG_BIN = ${builtins.toJSON (lib.getExe pkgs.ffmpeg-headless)}
    GEMINI_KEY_PATH = os.environ.get("MOLTIS_TTS_GEMINI_KEY_PATH", ${builtins.toJSON geminiKeyPath})
    HOST = os.environ.get("MOLTIS_TTS_SHIM_HOST", "127.0.0.1")
    PORT = int(os.environ.get("MOLTIS_TTS_SHIM_PORT", ${builtins.toJSON (toString ttsShimPort)}))


    def set_parent_death_signal():
        try:
            libc = ctypes.CDLL("libc.so.6", use_errno=True)
            # PR_SET_PDEATHSIG = 1
            libc.prctl(1, signal.SIGTERM, 0, 0, 0)
        except Exception:
            pass


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

        def do_POST(self):
            if self.path not in ("/v1/audio/speech", "/audio/speech"):
                self._send_json(404, {"error": {"message": "not found"}})
                return

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


    if __name__ == "__main__":
        set_parent_death_signal()
        with ReusableTCPServer((HOST, PORT), TtsHandler) as httpd:
            httpd.serve_forever()
  '';

  moltisInFenceLauncher = pkgs.writeShellApplication {
    name = "moltis-in-fence";
    runtimeInputs = [
      pkgs.ffmpeg-headless
      pkgs.python3
    ];
    text = ''
      ${moltisTtsShim} &
      exec ${lib.getExe pkgs.moltis} "$@"
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
  options.agentic.moltis.envPlumbing = lib.mkOption {
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

  options.agentic.moltis.renderedConfig = lib.mkOption {
    type = with lib.types; path;
    readOnly = true;
    description = ''
      Rendered `moltis.toml` for the child service to symlink into the
      writable Moltis config directory. The sops template substitutes the
      placeholder markers at render time, so the path is the only safe
      consumer: the generated file on any store path still holds markers.
    '';
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
      home.packages = [
        pkgs.moltis
        moltisFencedPackage
      ];

      home.shellAliases.moltis-log = "journalctl --user -u moltis.service";

      systemd.user.services.moltis = {
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

      agentic.moltis.renderedConfig = config.sops.templates."moltis.toml".path;

      sops.templates."moltis.toml" = {
        content = builtins.readFile (
          (pkgs.formats.toml { }).generate "moltis.toml" {
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

            # Moltis resolves `${VAR}` placeholders against the process
            # environment, and the config loader's second pass treats the
            # `[env]` table as an overrides map (crates/config/src/loader.rs,
            # tag 20260913.02). Placeholders here come from `envPlumbing`,
            # so no literal secret value ever enters a store path.
            env = envBlock;

            mcp.servers = mcpServerDefs.moltisServers;

            agents = {
              # Preset lane mapping. `coordinator` is the default spawn preset.
              # Every lane pins `reasoning_effort` explicitly. Model ids use
              # Moltis' `provider::model` namespace separator
              # (crates/providers/src/model_id.rs).
              default_preset = "coordinator";
              presets = {
                coordinator = {
                  model = "gemini::gemini-4-argon";
                  reasoning_effort = "medium";
                  delegate_only = true;
                };
                auxiliary = {
                  model = "gemini::gemini-3.8-flash";
                  reasoning_effort = "medium";
                };
                compression = {
                  model = "gemini::gemini-3.8-flash";
                  reasoning_effort = "medium";
                };
                review = {
                  model = "gemini::gemini-4-argon";
                  reasoning_effort = "medium";
                };
              };
            };

            # No inline `api_key`: Moltis does not expand `${VAR}` placeholders
            # inside provider `api_key` values, so `GEMINI_API_KEY` comes from
            # the process environment swept in by `[env]`.
            providers.gemini = {
              enabled = true;
              models = [
                "gemini-4-argon"
                "gemini-3.8-flash"
              ];
            };

            voice.tts = {
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
                group_policy = "allowlist";
                # Whole-file substitution resolves this from `[env]`, so the
                # channel id lives exactly once (loader second pass,
                # crates/config/src/loader/config_io.rs, tag 20260913.02).
                group_allowlist = [ "\${TELEGRAM_HOME_CHANNEL}" ];
                mention_mode = "always";
                untrusted_audience = "trusted";
                untrusted_tools = "policy";
                otp_self_approval = false;
                model = "gemini-4-argon";
                model_provider = "gemini";
              };
            };
          }
        );
        path = "${config.xdg.configHome}/moltis/moltis.toml";
      };
    }
  );
}
