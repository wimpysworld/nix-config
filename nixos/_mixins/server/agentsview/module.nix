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
  agentsviewPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agentsview;
  agentsviewConfigPython = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.tomlkit ]);
  agentsviewStateDir = "/var/lib/agentsview";
  agentsviewConfigPath = "${agentsviewStateDir}/config.toml";
in
lib.mkIf (noughtyLib.hostHasTag "agentsview") {
  # Static system user for the agentsview service. A static UID lets the sops
  # template that holds the PG URL be owned by `agentsview` directly, which is
  # simpler than the LoadCredential dance required by DynamicUser. This also
  # matches the static-user shape of the librechat hardening template the unit
  # below is based on.
  users.users.agentsview = {
    isSystemUser = true;
    group = "agentsview";
    description = "AgentsView read-only PostgreSQL dashboard";
  };
  users.groups.agentsview = { };

  systemd.services.agentsview = {
    description = "AgentsView read-only dashboard (PostgreSQL-backed)";
    after = [
      "postgresql.service"
      "network-online.target"
    ];
    wants = [
      "postgresql.service"
      "network-online.target"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      # AgentsView 0.29.0 takes host/port/base-path as CLI flags only; there
      # is no PG_SERVE / AGENTSVIEW_PORT / AGENTSVIEW_LISTEN env var. The only
      # env var consumed for `pg serve` is AGENTSVIEW_PG_URL, supplied via the
      # sops-templated EnvironmentFile. `--public-url` tells AgentsView which
      # browser origin (via Caddy) is trusted; without it, requests proxied
      # from the tailnet hostname prompt for a bearer token even though the
      # tailnet itself is the auth boundary.
      ExecStart = lib.concatStringsSep " " [
        "${agentsviewPackage}/bin/agentsview"
        "pg"
        "serve"
        "--host"
        "127.0.0.1"
        "--port"
        "18080"
        "--base-path"
        "/agentsview"
        "--public-url"
        "https://${config.noughty.host.name}.${config.noughty.network.tailNet}"
        "--no-browser"
        "--no-update-check"
      ];
      EnvironmentFile = config.sops.templates."agentsview.env".path;
      # AgentsView writes a small SQLite/cursor cache alongside its config; the
      # default location is $HOME/.agentsview, which for systemd-managed users
      # is /var/empty (read-only). Point it at the StateDirectory instead.
      Environment = [ "AGENTSVIEW_DATA_DIR=${agentsviewStateDir}" ];

      User = "agentsview";
      Group = "agentsview";
      StateDirectory = "agentsview";
      StateDirectoryMode = "0750";

      Restart = "on-failure";
      RestartSec = 5;

      # Hardening, copied from the librechat cloudflared-librechat unit
      # (nixos/_mixins/server/librechat/default.nix:212-247).
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

  # Seed the agentsview config.toml so `pg serve` accepts the tailnet
  # PostgreSQL URL. Agentsview's plaintext-PG guard refuses to connect
  # to a non-local host unless `pg.allow_insecure = true` is set, and
  # the tailnet hostname looks non-local from its perspective even
  # though the Tailscale boundary is the real auth and confidentiality
  # layer. Without this seed, `agentsview pg serve` exits before
  # binding :18080 and the unit restart-loops. The script mirrors the
  # producer-side activation in nixos/_mixins/server/hermes/default.nix
  # so behaviour stays consistent across producer and consumer
  # services; any pre-existing keys in the TOML are preserved.
  system.activationScripts.agentsview-config = lib.stringAfter [ "users" ] ''
    install -d -m 0750 -o agentsview -g agentsview ${agentsviewStateDir}

    ${agentsviewConfigPython}/bin/python - <<'PY'
    import pathlib
    import tomlkit

    path = pathlib.Path("${agentsviewConfigPath}")
    path.parent.mkdir(mode=0o750, parents=True, exist_ok=True)

    if path.exists() and path.is_file():
        document = tomlkit.parse(path.read_text(encoding="utf-8"))
    else:
        document = tomlkit.document()

    pg = document.get("pg")
    if pg is None or not hasattr(pg, "__setitem__"):
        pg = tomlkit.table()
        document["pg"] = pg

    pg["schema"] = "agentsview"
    pg["machine_name"] = "${host.name}"
    pg["allow_insecure"] = True

    tmp = path.with_name(f"{path.name}.tmp")
    tmp.write_text(tomlkit.dumps(document), encoding="utf-8")
    tmp.chmod(0o640)
    tmp.replace(path)
    PY

    chown agentsview:agentsview ${agentsviewConfigPath}
    chmod 0640 ${agentsviewConfigPath}
  '';
}
