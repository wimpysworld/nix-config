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
  claudePackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  codexPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  agentBrowserPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  # Determinate Nix binary, matching the host-level installation, so agent
  # shells expose the same `nix` CLI rather than stock upstream nixpkgs Nix.
  nixPackage = inputs.determinate.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
  hermesExtraPackages = with pkgs; [
    agentBrowserPackage
    bat
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
    gitMinimal
    gnugrep
    gnused
    gnutar
    gzip
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
    exec ${pkgs.bash}/bin/bash --noprofile --norc "\$@"
    EOF

    chmod 0555 "$out/bin/bash"
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

      GITHUB_TOKEN = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    sops.templates."hermes-env" = {
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
        ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
        CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
        GH_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        GITHUB_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        _HERMES_FORCE_TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        _HERMES_FORCE_ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
        _HERMES_FORCE_CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        _HERMES_FORCE_JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
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

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      package = hermesAgentPackage;
      environment = {
        TELEGRAM_HOME_CHANNEL = "-1003933927882";
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

        fallback_model = {
          provider = "copilot";
          model = "gpt-5.4";
        };

        tts = {
          provider = "edge";
          edge = {
            voice = "en-GB-SoniaNeural";
          };
        };

        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
          provider = "holographic";
        };
      };
    };

    systemd.services.hermes-agent.path = lib.mkBefore [ wrappedHermesBash ];
    systemd.services.hermes-agent.serviceConfig.ProtectHome = lib.mkForce true;
    # Keep service-created files group-accessible so the host user can inspect
    # and reuse shared state without fighting the upstream default umask.
    systemd.services.hermes-agent.serviceConfig.UMask = lib.mkForce "0007";

    systemd.tmpfiles.rules = lib.mkAfter [
      "d ${hermesHome}/skills 2770 ${hermesUser} ${hermesGroup} - -"
      "L+ ${hermesHome}/SOUL.md - - - - ${config.sops.templates."hermes-soul".path}"
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
