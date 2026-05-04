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
  cloudflareSopsFile = ../../../../secrets + "/cloudflare.yaml";
  hasCloudflareSopsFile = builtins.pathExists cloudflareSopsFile;
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
  hermesDashboardHost = "127.0.0.1";
  hermesDashboardPort = 9119;
  # Hermes 0.10 started enforcing owner-only chmods in several Python code paths
  # such as auth.json and cron state. That breaks this deployment because the
  # service account and the interactive host user intentionally share one
  # managed HERMES_HOME via the hermes group.
  hermesTuyaPythonPackages = with pkgs.python3Packages; [
    tinytuya
    tuyaha
  ];
  hermesTuyaPythonPath = pkgs.python3Packages.makePythonPath hermesTuyaPythonPackages;
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
            --set-default GNUPGHOME "${hermesGnupgHome}" \
            --set-default TRAYA_SANCTUARY_DIR "/var/lib/hermes/workspace/trayas-sanctuary" \
            --set-default TRAYA_SANCTUARY_REPO "the-cauldron/trayas-sanctuary" \
            --prefix PATH : "${lib.makeBinPath hermesExtraPackages}" \
            --prefix PYTHONPATH : "${hermesManagedPythonPath}:${hermesTuyaPythonPath}" \
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
  openhueConfigDir = "${config.services.hermes-agent.stateDir}/.openhue";
  openhueConfigPath = "${openhueConfigDir}/config.yaml";
  hermesSshDir = "${config.services.hermes-agent.stateDir}/.ssh";
  hermesGnupgHome = "${config.services.hermes-agent.stateDir}/.gnupg";
  # GPG runtime config for Traya's keyring. Loopback pinentry guards against
  # any tool that later tries to prompt for a passphrase; the key itself is
  # generated with %no-protection so there is nothing to prompt for.
  hermesGpgConf = pkgs.writeText "hermes-gpg.conf" ''
    pinentry-mode loopback
  '';
  hermesGpgAgentConf = pkgs.writeText "hermes-gpg-agent.conf" ''
    allow-loopback-pinentry
  '';
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
    getent
    gh
    himalaya
    gitMinimal
    gnugrep
    gnupg
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
    openhue-cli
    openssh
    poppler-utils
    procps
    python3
    python3Packages.tinytuya
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
    export GNUPGHOME=${hermesGnupgHome}
    export PYTHONPATH="${hermesManagedPythonPath}:${hermesTuyaPythonPath}:\''${PYTHONPATH-}"

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

    # Nixpkgs wires systemd's ssh proxy fragment into /etc/ssh/ssh_config by
    # default, which makes OpenSSH fail strict-mode checks on the resolved
    # store path with "Bad owner or permissions on .../20-systemd-ssh-proxy.conf".
    # The proxy plugin only matters for machinectl/container SSH which Traya
    # never uses, so disable the Include entirely and let plain ssh-to-remote
    # work for the hermes service user. Tracked upstream at
    # https://github.com/NixOS/nixpkgs/pull/495610 but fix hasn't reached us yet.
    programs.ssh.systemd-ssh-proxy.enable = false;

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

      WEBHOOK_SECRET = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      HUE_BRIDGE_IP = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      HUE_BRIDGE_APPLICATION_KEY = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      CLOUDFLARE_TUNNEL_TOKEN_HERMES_WEBHOOK = lib.mkIf hasCloudflareSopsFile {
        sopsFile = cloudflareSopsFile;
        path = "/run/secrets/CLOUDFLARE_TUNNEL_TOKEN_HERMES_WEBHOOK";
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

      SSH_PRIVATE_KEY = {
        sopsFile = trayaSopsFile;
        owner = hermesUser;
        group = hermesGroup;
        mode = "0400";
      };

      SSH_PUBLIC_KEY = {
        sopsFile = trayaSopsFile;
        owner = hermesUser;
        group = hermesGroup;
        mode = "0444";
      };

      GPG_PRIVATE_KEY = {
        sopsFile = trayaSopsFile;
        owner = hermesUser;
        group = hermesGroup;
        mode = "0400";
      };

      GPG_PUBLIC_KEY = {
        sopsFile = trayaSopsFile;
        owner = hermesUser;
        group = hermesGroup;
        mode = "0444";
      };

      GPG_KEY_ID = {
        sopsFile = trayaSopsFile;
        owner = hermesUser;
        group = hermesGroup;
        mode = "0444";
      };
    };

    sops.templates."hermes-env" = {
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
        WEBHOOK_ENABLED=true
        WEBHOOK_PORT=8644
        WEBHOOK_SECRET=${config.sops.placeholder.WEBHOOK_SECRET}
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

    sops.templates."hermes-gitconfig" = {
      content = ''
        [user]
            name = Traya
            email = traya@darth.cc
            signingkey = ${config.sops.placeholder.GPG_KEY_ID}

        [commit]
            gpgsign = true

        [tag]
            gpgsign = true

        [gpg]
            program = ${pkgs.gnupg}/bin/gpg2
      '';
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

    sops.templates."hermes-openhue-config" = {
      content = ''
        bridge: ${config.sops.placeholder.HUE_BRIDGE_IP}
        key: ${config.sops.placeholder.HUE_BRIDGE_APPLICATION_KEY}
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
        GNUPGHOME = hermesGnupgHome;
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
        openhue = {
          command = "${pkgs.openhue-cli}/bin/openhue";
          args = [ "mcp" ];
          env = {
            HOME = config.services.hermes-agent.stateDir;
          };
        };
        cloudflare = {
          url = "https://docs.mcp.cloudflare.com/mcp";
        };
      };

      # Upstream seeds these ${hermesHome}/.env.
      environmentFiles = [ config.sops.templates."hermes-env".path ];

      settings = {
        platforms = {
          webhook = {
            enabled = true;
            extra = {
              host = "127.0.0.1";
              port = 8644;
              secret = "\${WEBHOOK_SECRET}";
              routes.github-notifications = null;
            };
          };
        };

        model = {
          default = "gpt-5.5";
          provider = "openai-codex";
        };

        custom_providers = [
          {
            name = "skrye";
            base_url = "http://skrye.drongo-gamma.ts.net:8080/v1";
            model = "qwen3.6-35b-a3b";
            models = {
              "qwen3.6-35b-a3b" = {
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
              "qwen3.6-35b-a3b" = {
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

        auxiliary = {
          approval = {
            provider = "openai-codex";
            model = "gpt-5.3-codex-spark";
            timeout = 30;
          };
          session_search = {
            provider = "openai-codex";
            model = "gpt-5.3-codex-spark";
            timeout = 30;
            max_concurrency = 2;
          };
          skills_hub = {
            provider = "openai-codex";
            model = "gpt-5.3-codex-spark";
            timeout = 30;
          };
          mcp = {
            provider = "openai-codex";
            model = "gpt-5.3-codex-spark";
            timeout = 30;
          };
          web_extract = {
            provider = "openai-codex";
            model = "gpt-5.3-codex-spark";
            timeout = 30;
          };
        };

        providers = {
          anthropic = {
            allowed_models = [
              "claude-sonnet-4-6"
              "claude-opus-4-7"
            ];
          };
          openai-codex = {
            allowed_models = [
              "gpt-5.5"
              "gpt-5.3-codex-spark"
            ];
          };
        };

        fallback_providers = [
          {
            provider = "anthropic";
            model = "claude-opus-4-7";
          }
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
          provider = "holographic";
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

    # Upstream does not expose the dashboard through the NixOS module. Start it
    # separately so the CLI-managed web server can stay bound to localhost.
    systemd.services.hermes-agent-dashboard = {
      description = "Hermes Agent Web Dashboard";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "hermes-agent.service"
      ];
      environment = {
        GNUPGHOME = hermesGnupgHome;
        HERMES_HOME = hermesHome;
        HERMES_MANAGED = "true";
        HOME = config.services.hermes-agent.stateDir;
        TRAYA_SANCTUARY_DIR = "/var/lib/hermes/workspace/trayas-sanctuary";
        TRAYA_SANCTUARY_REPO = "the-cauldron/trayas-sanctuary";
      };
      path = [
        wrappedHermesBash
        hermesAgentPackage
      ]
      ++ hermesExtraPackages;
      serviceConfig = {
        User = hermesUser;
        Group = hermesGroup;
        WorkingDirectory = "/var/lib/hermes/workspace";
        ExecStart = "${hermesAgentPackage}/bin/hermes dashboard --host ${hermesDashboardHost} --port ${toString hermesDashboardPort} --no-open";
        Restart = "always";
        RestartSec = 5;
        UMask = "0007";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          config.services.hermes-agent.stateDir
          "/var/lib/hermes/workspace"
        ];
      };
    };

    services.caddy.virtualHosts."${config.noughty.host.name}.${config.noughty.network.tailNet}".extraConfig =
      lib.mkIf (config.services.caddy.enable && config.services.tailscale.enable) ''
        @hermesDashboard not path /syncthing* /netdata* /scrutiny* /novnc*
        reverse_proxy @hermesDashboard ${hermesDashboardHost}:${toString hermesDashboardPort} {
          header_up Host ${hermesDashboardHost}:${toString hermesDashboardPort}
        }
      '';

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

    systemd.services.cloudflared-hermes = lib.mkIf hasCloudflareSopsFile {
      description = "Cloudflare Tunnel connector for Hermes webhooks";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.cloudflared)
          "tunnel"
          "--no-autoupdate"
          "run"
          "--token-file"
          config.sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_HERMES_WEBHOOK.path
        ];
        Restart = lib.mkDefault "always";
        RestartSec = lib.mkDefault 5;
        User = lib.mkDefault "root";
        Group = lib.mkDefault "root";

        # Restrict the connector to outbound access and secret reads.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    # Create a dedicated remotely-managed Hermes tunnel in Cloudflare, then
    # encrypt its connector token into secrets/cloudflare.yaml as
    # CLOUDFLARE_TUNNEL_TOKEN_HERMES. Configure the published application in
    # Cloudflare to route the chosen webhook hostname to http://127.0.0.1:8644.

    systemd.tmpfiles.rules = lib.mkAfter [
      "d ${config.services.hermes-agent.stateDir}/.config 2750 ${hermesUser} ${hermesGroup} - -"
      "d ${himalayaConfigDir} 2750 ${hermesUser} ${hermesGroup} - -"
      "d ${hermesSshDir} 0700 ${hermesUser} ${hermesGroup} - -"
      "d ${hermesGnupgHome} 0700 ${hermesUser} ${hermesGroup} - -"
      "d ${hermesHome}/skills 2770 ${hermesUser} ${hermesGroup} - -"
      "d ${hermesHome}/skills/traya 2770 ${hermesUser} ${hermesGroup} - -"
      "d ${openhueConfigDir} 2770 ${hermesUser} ${hermesGroup} - -"
      "L+ ${himalayaConfigPath} - - - - ${config.sops.templates."hermes-himalaya-config".path}"
      "L+ ${openhueConfigPath} - - - - ${config.sops.templates."hermes-openhue-config".path}"
      "L+ ${hermesSshDir}/id_ed25519 - - - - ${config.sops.secrets.SSH_PRIVATE_KEY.path}"
      "L+ ${hermesSshDir}/id_ed25519.pub - - - - ${config.sops.secrets.SSH_PUBLIC_KEY.path}"
      "L+ ${hermesGnupgHome}/gpg.conf - - - - ${hermesGpgConf}"
      "L+ ${hermesGnupgHome}/gpg-agent.conf - - - - ${hermesGpgAgentConf}"
      "L+ ${config.services.hermes-agent.stateDir}/.gitconfig - - - - ${
        config.sops.templates."hermes-gitconfig".path
      }"
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

    system.activationScripts.hermes-agent-gpg-import =
      lib.stringAfter [ "hermes-agent-setup" "specialfs" ]
        ''
          # Import Traya's GPG key into the hermes user's keyring so git commit
          # signing and encryption work without per-session setup. Idempotent:
          # gpg silently ignores already-imported keys. Ultimate trust so the
          # key signs without warnings. gpg.conf and gpg-agent.conf are
          # provisioned via tmpfiles symlinks into the Nix store.
          if [ -f ${config.sops.secrets.GPG_PRIVATE_KEY.path} ] \
             && [ -f ${config.sops.secrets.GPG_KEY_ID.path} ]; then
            install -d -m 0700 -o ${hermesUser} -g ${hermesGroup} ${hermesGnupgHome}

            ${pkgs.util-linux}/bin/runuser -u ${hermesUser} -- \
              env GNUPGHOME=${hermesGnupgHome} \
              ${pkgs.gnupg}/bin/gpg --batch --quiet --import \
              ${config.sops.secrets.GPG_PRIVATE_KEY.path} || true

            fpr=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.GPG_KEY_ID.path})
            if [ -n "$fpr" ]; then
              ${pkgs.util-linux}/bin/runuser -u ${hermesUser} -- \
                env GNUPGHOME=${hermesGnupgHome} \
                ${pkgs.bash}/bin/bash -c "echo \"$fpr:6:\" | ${pkgs.gnupg}/bin/gpg --batch --import-ownertrust" || true
            fi
          fi
        '';
  };
}
