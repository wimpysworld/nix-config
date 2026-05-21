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
  inherit (pkgs.stdenv.hostPlatform) system;
  agentsviewPackage = inputs.llm-agents.packages.${system}.agentsview;
  agentsviewSopsFile = ../../../../secrets/agentsview.yaml;
  agentsviewConfigPath = "${config.home.homeDirectory}/.agentsview/config.toml";
  agentsviewEnvPath = config.sops.templates."agentsview-pg.env".path;
  agentsviewConfigPython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  agentsviewConfigActivationScript = ''
    ${agentsviewConfigPython}/bin/python - <<'PY'
    import pathlib

    import tomlkit

    path = pathlib.Path("${agentsviewConfigPath}")
    env_path = pathlib.Path("${agentsviewEnvPath}")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)

    if path.exists() and path.is_file():
        document = tomlkit.parse(path.read_text(encoding="utf-8"))
    else:
        document = tomlkit.document()

    pg = document.get("pg")
    if pg is None or not hasattr(pg, "__setitem__"):
        pg = tomlkit.table()
        document["pg"] = pg

    for line in env_path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator and key == "AGENTSVIEW_PG_URL":
            pg["url"] = value
            break
    else:
        raise RuntimeError(f"AGENTSVIEW_PG_URL is missing from {env_path}")

    pg["schema"] = "agentsview"
    pg["machine_name"] = "${host.name}"
    pg["allow_insecure"] = True

    tmp = path.with_name(f"{path.name}.tmp")
    tmp.write_text(tomlkit.dumps(document), encoding="utf-8")
    tmp.chmod(0o600)
    tmp.replace(path)
    PY
  '';
in
lib.mkIf (noughtyLib.userHasTag "developer") {
  sops.secrets.AGENTSVIEW_PG_URL = {
    sopsFile = agentsviewSopsFile;
    mode = "0400";
  };

  sops.templates."agentsview-pg.env" = {
    content = ''
      AGENTSVIEW_PG_URL=${config.sops.placeholder.AGENTSVIEW_PG_URL}
      AGENTSVIEW_PG_SCHEMA=agentsview
      AGENTSVIEW_PG_MACHINE=${host.name}
      AGENTSVIEW_DISABLE_UPDATE_CHECK=1
    '';
    mode = "0400";
  };

  home.packages = [
    agentsviewPackage
  ];

  home.activation.agentsviewConfig = lib.hm.dag.entryAfter [
    "writeBoundary"
  ] agentsviewConfigActivationScript;

  systemd.user.services.agentsview-pg-push = lib.mkIf host.is.linux {
    Unit = {
      Description = "Push local AgentsView data to PostgreSQL";
      After = [
        "sops-nix.service"
      ];
      Wants = [
        "sops-nix.service"
      ];
    };

    Service = {
      Type = "exec";
      EnvironmentFile = config.sops.templates."agentsview-pg.env".path;
      ExecStart = "${agentsviewPackage}/bin/agentsview pg push";
    };
  };

  systemd.user.timers.agentsview-pg-push = lib.mkIf host.is.linux {
    Unit.Description = "Push local AgentsView data to PostgreSQL on a schedule";

    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "15m";
      RandomizedDelaySec = "2m";
      Persistent = true;
      Unit = "agentsview-pg-push.service";
    };

    Install.WantedBy = [
      "timers.target"
    ];
  };
}
