{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
# Network exposure policy (proposal Risk 5):
# PostgreSQL listens on every interface (listen_addresses = '*') and access is
# restricted in `authentication` (pg_hba.conf). The tailscale interface is the
# only non-loopback access path and is treated as trusted (no host-firewall
# rules). Tailscale's default CGNAT ranges (100.64.0.0/10 for IPv4 and
# fd7a:115c:a1e0::/48 for IPv6) gate access to the `agentsview` database.
# No 0.0.0.0/0 rule.
lib.mkIf (noughtyLib.hostHasTag "postgres") {
  sops.secrets.AGENTSVIEW_PG_PASSWORD = {
    sopsFile = ../../../../secrets/agentsview.yaml;
    path = "/run/secrets/AGENTSVIEW_PG_PASSWORD";
    owner = "postgres";
    group = "postgres";
    mode = "0400";
  };

  services.postgresql = {
    enable = true;
    # Pin to postgresql_18 (18.4): latest upstream stable, available in both
    # nixpkgs 25.11 and nixpkgs-unstable (proxy for 26.05). Pinning explicitly
    # means the channel bump will not silently migrate the data directory to a
    # newer major; revisit with pg_upgrade when 19 lands and matures.
    package = pkgs.postgresql_18;

    ensureDatabases = [ "agentsview" ];
    ensureUsers = [
      {
        name = "agentsview";
        ensureDBOwnership = true;
      }
    ];

    settings = {
      # Force "*" because the upstream NixOS module sets a non-mkDefault value
      # for `listen_addresses` (loopback only); without mkForce, `mkDefault "*"`
      # loses the priority fight and PG only binds 127.0.0.1 / ::1. Access is
      # still tightly restricted at the pg_hba layer below.
      listen_addresses = lib.mkForce "*";

      # Aggressive-but-safe autovacuum + maintenance tuning. revan's root
      # filled because a high-churn table's GIN trgm index bloated unbounded
      # under default autovacuum thresholds (20% scale factor, 1min naptime).
      # These knobs run autovacuum more often and let it do more work per pass
      # so dead tuples and index bloat get reclaimed before they become a
      # disk-pressure incident. Per-table storage params (e.g. lower local
      # scale_factors) and `fastupdate=off` on the GIN trgm index are applied
      # live in the DB catalog by the AgentsView app at table/index creation
      # time, not declaratively from nix.
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
      # TYPE  DATABASE     USER         ADDRESS              METHOD
      local   all          all                               peer
      host    all          all          127.0.0.1/32         scram-sha-256
      host    all          all          ::1/128              scram-sha-256
      host    agentsview   agentsview   100.64.0.0/10        scram-sha-256
      host    agentsview   agentsview   fd7a:115c:a1e0::/48  scram-sha-256
    '';
  };

  # Apply the agentsview role password from sops after the upstream
  # postgresql-setup oneshot has created the role via `ensureUsers`. Attaching
  # to `postgresql.service.postStart` is too early in NixOS 25.11 because role
  # creation moved into a separate `postgresql-setup.service` unit. `ALTER ROLE`
  # is idempotent and re-applies on every restart of postgresql-setup, so this
  # also handles password rotation (rotate the sops value, then
  # `systemctl restart postgresql-setup.service`).
  systemd.services.postgresql-setup.postStart = lib.mkAfter ''
    ${config.services.postgresql.package}/bin/psql -h /run/postgresql --no-psqlrc -v ON_ERROR_STOP=1 <<'SQL'
    \set role_password `${pkgs.coreutils}/bin/cat ${config.sops.secrets.AGENTSVIEW_PG_PASSWORD.path}`
    ALTER ROLE agentsview WITH PASSWORD :'role_password';
    SQL

    # Remove the old local GIN fastupdate workaround now that AgentsView owns
    # its PostgreSQL index maintenance upstream. The event trigger persists in
    # the database until dropped, even after the Nix config stops creating it.
    ${config.services.postgresql.package}/bin/psql -h /run/postgresql -d agentsview --no-psqlrc -v ON_ERROR_STOP=1 <<'SQL'
    DROP EVENT TRIGGER IF EXISTS gin_fastupdate_off_trg;
    DROP FUNCTION IF EXISTS public.gin_fastupdate_off();
    SQL
  '';

  # Native pg_dump backups to /mnt/snapshot/backup-postgres. Retention policy
  # deferred (proposal Risk 7); revisit when /mnt/snapshot pressure warrants.
  services.postgresqlBackup = {
    enable = true;
    databases = [ "agentsview" ];
    location = "/mnt/snapshot/backup-postgres";
    compression = "zstd";
  };

  systemd.tmpfiles.rules = [
    "d /mnt/snapshot/backup-postgres 0700 postgres postgres -"
  ];

  environment.shellAliases.postgresql-log = "journalctl _SYSTEMD_UNIT=postgresql.service";
}
