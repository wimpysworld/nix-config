{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  aiSopsFile = ../../../../secrets + "/ai.yaml";
  bondSopsFile = ../../../../secrets + "/hermes-bond.yaml";
  hermesSopsFile = ../../../../secrets + "/hermes.yaml";
  mcpSopsFile = ../../../../secrets + "/mcp.yaml";
  trayaSopsFile = ../../../../secrets + "/traya.yaml";
  claudePackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  codexPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  agentBrowserPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  # Determinate Nix CLI, matching the host-level installation, so agent shells
  # expose the same `nix` CLI rather than stock upstream nixpkgs Nix. The
  # `determinate` flake's `packages.default` is `determinate-nixd` (the daemon
  # helper); the actual `nix` CLI lives in its `nix` input.
  nixPackage = inputs.determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
  # Hermes 0.10 started enforcing owner-only chmods in several Python code paths
  # such as auth.json and cron state. That breaks this deployment because the
  # service account and the interactive host user intentionally share one
  # managed HERMES_HOME via the hermes group.
  hermesManagedPythonPath = pkgs.writeTextDir "sitecustomize.py" ''
    """Keep managed Hermes state group-accessible and patch doctor checks."""

    import builtins
    import os
    import shutil
    from pathlib import Path


    def _managed_mode_enabled() -> bool:
        return os.environ.get("HERMES_MANAGED", "").strip().lower() in {
            "1",
            "true",
            "yes",
            "nixos",
        }


    def _translate_managed_mode(path_like: os.PathLike[str] | str, mode: int) -> int:
        # Only rewrite chmod calls inside the managed Hermes state tree. This
        # leaves unrelated files alone while keeping shared state readable and
        # writable by both the service user and host users in the hermes group.
        hermes_home_raw = os.environ.get("HERMES_HOME", "").strip()
        if not hermes_home_raw or not _managed_mode_enabled():
            return mode

        hermes_home = Path(hermes_home_raw).resolve()
        candidate = Path(path_like).resolve()

        try:
          candidate.relative_to(hermes_home)
        except ValueError:
          return mode

        if mode == 0o600:
          return 0o660

        if mode == 0o700:
          # Directories keep setgid so new files inherit the hermes group.
          return 0o2770 if candidate.is_dir() else 0o770

        return mode


    if _managed_mode_enabled():
        # Patch chmod at interpreter startup so upstream Python modules do not
        # need to know about this NixOS shared-state layout.
        _original_os_chmod = os.chmod
        _original_path_chmod = Path.chmod
        _original_import = builtins.__import__

        def _managed_os_chmod(path_like, mode, *args, **kwargs):
            return _original_os_chmod(
                path_like,
                _translate_managed_mode(path_like, mode),
                *args,
                **kwargs,
            )

        def _managed_path_chmod(self, mode, *args, **kwargs):
            return _original_path_chmod(
                self,
                _translate_managed_mode(self, mode),
                *args,
                **kwargs,
            )

        def _patch_doctor_module(module) -> None:
            if getattr(module, "_noughty_doctor_patch_applied", False):
                return

            original_run_doctor = getattr(module, "run_doctor", None)
            if original_run_doctor is None:
                return

            def _patched_run_doctor(args):
                original_exists = Path.exists

                def _doctor_exists(self):
                    # Hermes doctor assumes agent-browser lives under the
                    # packaged project root's node_modules tree. In this NixOS
                    # deployment it is provided as a separate package on PATH.
                    probe = module.PROJECT_ROOT / "node_modules" / "agent-browser"
                    resolved = shutil.which("agent-browser")
                    if self == probe and resolved:
                        return True
                    return original_exists(self)

                Path.exists = _doctor_exists
                try:
                    return original_run_doctor(args)
                finally:
                    Path.exists = original_exists

            module.run_doctor = _patched_run_doctor
            module._noughty_doctor_patch_applied = True

        def _managed_import(name, globals=None, locals=None, fromlist=(), level=0):
            module = _original_import(name, globals, locals, fromlist, level)

            if name == "hermes_cli.doctor":
                _patch_doctor_module(module)
                builtins.__import__ = _original_import
            elif name == "hermes_cli" and fromlist and "doctor" in fromlist:
                doctor_module = getattr(module, "doctor", None)
                if doctor_module is not None:
                    _patch_doctor_module(doctor_module)
                    builtins.__import__ = _original_import

            return module

        os.chmod = _managed_os_chmod
        Path.chmod = _managed_path_chmod
        builtins.__import__ = _managed_import
  '';
  upstreamHermesAgentPackage = pkgs.hermesAgent;
  hermesAgentPackage = pkgs.symlinkJoin {
    name = "hermes-agent-host";
    paths = [ upstreamHermesAgentPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # Wrap the upstream CLI so manual invocations use the managed state dir
      # and load the chmod shim above before Hermes imports its Python modules.
      # Also prepend the extra toolset here because services.hermes-agent.extraPackages
      # only affects the systemd unit, not host-side `hermes` invocations.
      for program in hermes hermes-agent hermes-acp; do
        if [ -x "$out/bin/$program" ]; then
          wrapProgram "$out/bin/$program" \
            --set-default HERMES_HOME "${hermesHome}" \
            --set-default TRAYA_SANCTUARY_DIR "/var/lib/hermes/workspace/trayas-sanctuary" \
            --set-default TRAYA_SANCTUARY_REPO "the-cauldron/trayas-sanctuary" \
            --prefix PATH : "${lib.makeBinPath hermesExtraPackages}" \
            --prefix PYTHONPATH : "${hermesManagedPythonPath}" \
            --set-default HERMES_MANAGED "true"
        fi
      done
    '';
  };
  hermesUser = config.services.hermes-agent.user;
  hermesGroup = config.services.hermes-agent.group;
  hermesAuthFile = "${hermesHome}/auth.json";
  himalayaConfigDir = "${config.services.hermes-agent.stateDir}/.config/himalaya";
  himalayaConfigPath = "${himalayaConfigDir}/config.toml";
  hermesExtraPackages = with pkgs; [
    agentBrowserPackage
    bat
    bubblewrap
    bzip2
    claudePackage
    codexPackage
    nixPackage
    (curlMinimal.override { opensslSupport = true; })
    duf
    dua
    fd
    ffmpeg
    findutils
    fzf
    gh
    himalaya
    gitMinimal
    gnugrep
    gnused
    gnutar
    gzip
    inetutils
    jq
    just
    lsof
    ltrace
    lurk
    mawk
    nh
    nix-direnv
    nodejs-slim
    poppler-utils
    procps
    python3Minimal
    rclone
    ripgrep
    rsync
    sd
    systemdMinimal
    tree
    unzip
    util-linux
    uv
    wget
    wrangler
    xz
    yq
  ];
  wrappedHermesBash = pkgs.runCommand "hermes-wrapped-bash" { } ''
    mkdir -p "$out/bin"

    cat > "$out/bin/bash" <<EOF
    #!${pkgs.bash}/bin/bash
    export PATH="$out/bin:${
      lib.makeBinPath (
        [
          pkgs.coreutils
          hermesAgentPackage
        ]
        ++ hermesExtraPackages
      )
    }"
    export TRAYA_SANCTUARY_DIR="/var/lib/hermes/workspace/trayas-sanctuary"
    export TRAYA_SANCTUARY_REPO="the-cauldron/trayas-sanctuary"

    # Interactive CLI sandboxing: systemd hardening does not apply to host
    # shells, so we reuse bubblewrap to hide the same paths the gateway
    # service blocks. bwrap sets up a user namespace where the caller keeps
    # their real UID -- agents like claude-code refuse to run as root, so
    # unshare -r is not usable here -- and shadows each target with an
    # empty tmpfs visible only inside the sandbox. /run/current-system is a
    # symlink, so we shadow its resolved store path. The HERMES_SANDBOXED
    # guard stops recursive wrapping when an inner shell re-execs us.
    if [ -z "\''${HERMES_SANDBOXED-}" ] && [ -x ${pkgs.bubblewrap}/bin/bwrap ]; then
      export HERMES_SANDBOXED=1
      _hermes_current_system=\$(${pkgs.coreutils}/bin/readlink -f /run/current-system 2>/dev/null || true)
      _hermes_booted_system=\$(${pkgs.coreutils}/bin/readlink -f /run/booted-system 2>/dev/null || true)
      _hermes_extra_shadow=()
      if [ -n "\$_hermes_current_system" ] && [ -d "\$_hermes_current_system" ]; then
        _hermes_extra_shadow+=(--tmpfs "\$_hermes_current_system")
      fi
      if [ -n "\$_hermes_booted_system" ] && [ -d "\$_hermes_booted_system" ] \
        && [ "\$_hermes_booted_system" != "\$_hermes_current_system" ]; then
        _hermes_extra_shadow+=(--tmpfs "\$_hermes_booted_system")
      fi
      exec ${pkgs.bubblewrap}/bin/bwrap \
        --dev-bind / / \
        --tmpfs /mnt \
        --tmpfs /srv \
        "\''${_hermes_extra_shadow[@]}" \
        --die-with-parent \
        -- \
        ${pkgs.bash}/bin/bash --noprofile --norc "\$@"
    fi

    exec ${pkgs.bash}/bin/bash --noprofile --norc "\$@"
    EOF

    chmod 0555 "$out/bin/bash"
    ln -s bash "$out/bin/sh"
  '';
  username = config.noughty.user.name;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "hermes") {
    users.users.hermes.uid = 1984;
    users.users.hermes.packages = [
      wrappedHermesBash
      hermesAgentPackage
    ]
    ++ hermesExtraPackages;
    users.groups.hermes.gid = 1984;
    users.users.${username}.extraGroups = lib.mkAfter [ "hermes" ];

    sops.secrets = {
      TELEGRAM_BOT_TOKEN = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      TELEGRAM_ALLOWED_USERS = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      BOND_MD = {
        sopsFile = bondSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      ANTHROPIC_API_KEY = {
        sopsFile = aiSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      CONTEXT7_API_KEY = {
        sopsFile = mcpSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      JINA_API_KEY = {
        sopsFile = mcpSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      COPILOT_GITHUB_TOKEN = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      GITHUB_TOKEN = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      HONCHO_API_KEY = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      EMAIL_ADDRESS = {
        sopsFile = trayaSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      EMAIL_PASSWORD = {
        sopsFile = trayaSopsFile;
        owner = hermesUser;
        group = hermesGroup;
        mode = "0440";
      };
    };

    sops.templates."hermes-env" = {
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
        ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
        CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
        COPILOT_GITHUB_TOKEN=${config.sops.placeholder.COPILOT_GITHUB_TOKEN}
        GH_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        GITHUB_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        _HERMES_FORCE_TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        _HERMES_FORCE_ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
        _HERMES_FORCE_CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        _HERMES_FORCE_JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
        _HERMES_FORCE_COPILOT_GITHUB_TOKEN=${config.sops.placeholder.COPILOT_GITHUB_TOKEN}
        _HERMES_FORCE_GH_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        _HERMES_FORCE_GITHUB_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.templates."hermes-soul" = {
      content = ''
        ${builtins.readFile ./traya-soul.md}
        ${config.sops.placeholder.BOND_MD}
      '';
      owner = "root";
      group = "root";
      mode = "0644";
    };

    sops.templates."hermes-honcho" = {
      content = builtins.toJSON {
        apiKey = config.sops.placeholder.HONCHO_API_KEY;
        baseUrl = "https://api.honcho.dev";
        workspace = "darth.cc";
        peerName = "martin";
        hosts = {
          hermes = {
            enabled = true;
            aiPeer = "traya";
            workspace = "Hermes";
            peerName = "martin";
            recallMode = "hybrid";
            writeFrequency = "async";
            sessionStrategy = "per-directory";
            dialecticReasoningLevel = "low";
            dialecticDynamic = true;
            dialecticCadence = 3;
            dialecticDepth = 1;
            contextCadence = 1;
            contextTokens = 1200;
            dialecticMaxChars = 600;
            messageMaxChars = 25000;
            saveMessages = true;
            observation = {
              user = {
                observeMe = true;
                observeOthers = true;
              };
              ai = {
                observeMe = true;
                observeOthers = true;
              };
            };
          };
        };
      };
      owner = hermesUser;
      group = hermesGroup;
      mode = "0440";
    };

    sops.templates."hermes-himalaya-config" = {
      content = ''
        display-name = "Traya"

        [accounts.fastmail]
        default = true
        email = "${config.sops.placeholder.EMAIL_ADDRESS}"
        display-name = "Traya"

        folder.aliases.inbox = "INBOX"
        folder.aliases.sent = "Sent"
        folder.aliases.drafts = "Drafts"
        folder.aliases.trash = "Trash"

        backend.type = "imap"
        backend.host = "imap.fastmail.com"
        backend.port = 993
        backend.encryption.type = "tls"
        backend.login = "${config.sops.placeholder.EMAIL_ADDRESS}"
        backend.auth.type = "password"
        backend.auth.cmd = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.EMAIL_PASSWORD.path}"

        message.send.backend.type = "smtp"
        message.send.backend.host = "smtp.fastmail.com"
        message.send.backend.port = 465
        message.send.backend.encryption.type = "tls"
        message.send.backend.login = "${config.sops.placeholder.EMAIL_ADDRESS}"
        message.send.backend.auth.type = "password"
        message.send.backend.auth.cmd = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.EMAIL_PASSWORD.path}"
      '';
      owner = hermesUser;
      group = hermesGroup;
      mode = "0440";
    };

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      package = hermesAgentPackage;
      environment = {
        TELEGRAM_HOME_CHANNEL = "-1003933927882";
        TRAYA_SANCTUARY_DIR = "/var/lib/hermes/workspace/trayas-sanctuary";
        TRAYA_SANCTUARY_REPO = "the-cauldron/trayas-sanctuary";
      };
      extraPackages = [
        wrappedHermesBash
        hermesAgentPackage
      ]
      ++ hermesExtraPackages;
      mcpServers = {
        exa = {
          url = "https://mcp.exa.ai/mcp";
        };
        context7 = {
          url = "https://mcp.context7.com/mcp";
          headers = {
            Authorization = "Bearer \${CONTEXT7_API_KEY}";
          };
        };
        nixos = {
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          args = [ ];
        };
        cloudflare = {
          url = "https://docs.mcp.cloudflare.com/mcp";
        };
      };

      # Upstream seeds these ${hermesHome}/.env.
      environmentFiles = [ config.sops.templates."hermes-env".path ];

      settings = {
        model = {
          default = "gpt-5.4";
          provider = "openai-codex";
        };

        custom_providers = [
          {
            name = "skrye";
            base_url = "http://skrye.drongo-gamma.ts.net:8080/v1";
            model = "qwen3.5-35b-a3b";
            models = {
              "qwen3.5-35b-a3b" = {
                context_length = 262144;
              };
            };
          }
          {
            name = "zannah";
            base_url = "http://zannah.drongo-gamma.ts.net:8080/v1";
            model = "qwen3-coder-next";
            models = {
              qwen3-coder-next = {
                context_length = 262144;
              };
              "qwen3.5-35b-a3b" = {
                context_length = 262144;
              };
            };
          }
        ];

        terminal = {
          backend = "local";
          cwd = "/var/lib/hermes/workspace";
          timeout = 180;
          persistent_shell = true;
          env_passthrough = [
            "TERM"
            "COLORTERM"
          ];
        };

        providers = {
          anthropic = {
            allowed_models = [
              "claude-sonnet-4-6"
              "claude-opus-4-6"
            ];
          };
          copilot = {
            allowed_models = [ "gpt-5.4" ];
          };
          openai-codex = {
            allowed_models = [ "gpt-5.4" ];
          };
        };

        fallback_providers = [
          { provider = "copilot"; model = "gpt-5.4"; }
          { provider = "anthropic"; model = "claude-opus-4-6"; }
        ];

        tts = {
          provider = "edge";
          edge = {
            voice = "en-GB-SoniaNeural";
          };
        };

        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
          provider = "honcho";
        };

        # Full autonomous operation: skip all approval prompts for commands
        # flagged as "dangerous" by upstream pattern matching. The service
        # already runs under systemd hardening (ProtectHome, InaccessiblePaths)
        # and interactive host shells are wrapped with bubblewrap, so the
        # prompt-level guard is redundant and blocks headless gateway use.
        approvals = {
          mode = "off";
          cron_mode = "approve";
        };
      };
    };

    systemd.services.hermes-agent.path = lib.mkBefore [ wrappedHermesBash ];
    systemd.services.hermes-agent.serviceConfig.ProtectHome = lib.mkForce true;
    # Keep service-created files group-accessible so the host user can inspect
    # and reuse shared state without fighting the upstream default umask.
    systemd.services.hermes-agent.serviceConfig.UMask = lib.mkForce "0007";
    # Hide host-sensitive trees from the service and any processes it spawns.
    # InaccessiblePaths makes the target appear as an empty, immutable mount
    # inside the service's mount namespace, so shell tools (ls, cat, find,
    # rclone, rsync, etc.) cannot list or read them.
    systemd.services.hermes-agent.serviceConfig.InaccessiblePaths = [
      "/mnt"
      "/srv"
      "/run/current-system"
      "/run/booted-system"
    ];

    systemd.tmpfiles.rules = lib.mkAfter [
      "d ${config.services.hermes-agent.stateDir}/.config 2750 ${hermesUser} ${hermesGroup} - -"
      "d ${himalayaConfigDir} 2750 ${hermesUser} ${hermesGroup} - -"
      "d ${hermesHome}/skills 2770 ${hermesUser} ${hermesGroup} - -"
      "d ${hermesHome}/skills/traya 2770 ${hermesUser} ${hermesGroup} - -"
      "L+ ${himalayaConfigPath} - - - - ${config.sops.templates."hermes-himalaya-config".path}"
      "L+ ${hermesHome}/SOUL.md - - - - ${config.sops.templates."hermes-soul".path}"
      "L+ ${hermesHome}/honcho.json - - - - ${config.sops.templates."hermes-honcho".path}"
    ];

    system.activationScripts.hermes-agent-skills-permissions =
      lib.stringAfter [ "hermes-agent-setup" ]
        ''
          # Repair permissions after activation because Hermes can rewrite some
          # runtime files with owner-only modes during normal CLI or service use.
          for sharedDir in \
            ${hermesHome}/cron \
            ${hermesHome}/logs \
            ${hermesHome}/memories \
            ${hermesHome}/sessions \
            ${hermesHome}/skills
          do
            mkdir -p "$sharedDir"
            chown ${hermesUser}:${hermesGroup} "$sharedDir"
            chmod 2770 "$sharedDir"

            find "$sharedDir" -type d \
              -exec chown ${hermesUser}:${hermesGroup} {} + \
              -exec chmod 2770 {} + 2>/dev/null || true

            find "$sharedDir" -type f \
              -exec chown ${hermesUser}:${hermesGroup} {} + \
              -exec chmod 0660 {} + 2>/dev/null || true
          done

          for sharedFile in \
            ${hermesHome}/.env \
            ${hermesHome}/config.yaml
          do
            if [ -f "$sharedFile" ]; then
              chown ${hermesUser}:${hermesGroup} "$sharedFile"
              chmod 0640 "$sharedFile"
            fi
          done

          if [ -f ${hermesAuthFile} ]; then
            # Interactive CLI use can rewrite auth.json with a different owner.
            # Keep it group-writable so the service and host user share auth
            # state and token refreshes do not lock each other out.
            chown ${hermesUser}:${hermesGroup} ${hermesAuthFile}
            chmod 0660 ${hermesAuthFile}
          fi
        '';
  };
}
