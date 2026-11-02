{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  hasSilo = noughtyLib.hostHasTag "silo";
in
lib.mkIf (noughtyLib.hostHasTag "postgres") {
  services.postgresql = {
    enable = true;
    # Pin to postgresql_18: latest upstream stable, available in both
    # nixpkgs 25.11 and nixpkgs-unstable. Pinning explicitly means a channel
    # bump will not silently migrate the data directory to a newer major.
    package = pkgs.postgresql_18;
    extensions =
      ps: with ps; [
        pgvector
      ];

    ensureDatabases = lib.optional hasSilo "silo";
    ensureUsers = lib.optional hasSilo {
      name = "silo";
      ensureDBOwnership = true;
    };

    settings = {
      shared_preload_libraries = "pg_stat_statements";

      # Aggressive-but-safe autovacuum and maintenance tuning so high-churn
      # tables and GIN trigram indexes reclaim dead tuples promptly.
      autovacuum = "on";
      autovacuum_naptime = "30s";
      autovacuum_vacuum_scale_factor = 0.05;
      autovacuum_vacuum_insert_scale_factor = 0.05;
      autovacuum_analyze_scale_factor = 0.02;
      autovacuum_vacuum_cost_limit = 2000;
      log_autovacuum_min_duration = "1s";
      maintenance_work_mem = "512MB";
    };

    authentication = lib.mkOverride 10 ''
      # TYPE  DATABASE  USER  ADDRESS       METHOD
      local   all       all                 peer
      host    all       all   127.0.0.1/32  scram-sha-256
      host    all       all   ::1/128       scram-sha-256
    '';
  };

  # Pre-create extensions required by Silo as the postgres superuser after
  # postgresql-setup has created the silo database and role. Non-superuser
  # application roles cannot create extensions that require superuser
  # privileges such as pg_stat_statements or untrusted C extensions.
  systemd.services.postgresql-setup.postStart = lib.mkIf hasSilo (
    lib.mkAfter ''
      ${config.services.postgresql.package}/bin/psql -h /run/postgresql -d silo --no-psqlrc -v ON_ERROR_STOP=1 <<'SQL'
      CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;
      CREATE EXTENSION IF NOT EXISTS pg_trgm;
      CREATE EXTENSION IF NOT EXISTS citext;
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      SQL
    ''
  );

  # Native pg_dump backups to /mnt/snapshot/backup-postgres.
  services.postgresqlBackup = {
    enable = true;
    databases = lib.optional hasSilo "silo";
    location = "/mnt/snapshot/backup-postgres";
    compression = "zstd";
  };

  systemd.services.${if hasSilo then "postgresqlBackup-silo" else "postgresqlBackup"}.unitConfig = {
    RequiresMountsFor = [ "/mnt/snapshot" ];
    ConditionPathIsMountPoint = "/mnt/snapshot";
  };

  systemd.tmpfiles.rules = [
    "d /mnt/snapshot/backup-postgres 0700 postgres postgres -"
  ];

  environment.shellAliases.postgresql-log = "journalctl _SYSTEMD_UNIT=postgresql.service";
}
