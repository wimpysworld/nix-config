{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  # The capture helper is a self-contained writeShellApplication. Using
  # the udev -> systemd handoff pattern keeps the long-running zstd
  # compression off the udev event thread, which would otherwise kill
  # the worker after a few seconds.
  devcoredumpCapture = pkgs.callPackage ./devcoredump-capture { };
in
# Apply on Linux hosts where an AMD GPU is present. The mechanism is
# generic to any driver that emits a devcoredump, but scoping
# conservatively to AMD GPU hosts matches the immediate need (Strix
# Halo VPE/SMU video-decode hangs). Lift the gate later if broader
# coverage is wanted.
lib.mkIf (host.is.linux && host.gpu.hasAmd && !host.is.iso) {

  # Persistent output directory for captured artefacts. Mode 0750 keeps
  # the dumps readable only by root and the wheel group; coredumps may
  # contain sensitive memory contents.
  systemd.tmpfiles.rules = [
    "d /var/lib/devcoredump 0750 root root -"
  ];

  # Make the helper available on PATH so an operator can replay a
  # capture by hand against a fresh devcdN entry.
  environment.systemPackages = [ devcoredumpCapture ];

  # Trigger the systemd template unit when the kernel adds a new
  # devcoredump entry. Running the capture directly from udev is not
  # safe: udev kills workers that take more than a few seconds, and
  # zstd -19 over a multi-megabyte dump easily exceeds that budget.
  services.udev.extraRules = ''
    SUBSYSTEM=="devcoredump", ACTION=="add", KERNEL=="devcd[0-9]*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="devcoredump-capture@%k.service"
  '';

  # Template unit; the instance name (%i) is the devcdN kernel name
  # passed through from the udev rule via SYSTEMD_WANTS.
  systemd.services."devcoredump-capture@" = {
    description = "Capture kernel devcoredump %i before auto-expiry";
    documentation = [ "https://www.kernel.org/doc/html/latest/driver-api/dev-coredump.html" ];

    # Run as soon as the basic system is up. Devcoredumps appear early
    # during boot in some scenarios, so do not wait for multi-user.
    after = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];

    # Avoid restart storms if a particular dump trips a bug in the
    # capture path. A single best-effort attempt is sufficient: the
    # kernel will still expire the entry on its own.
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${devcoredumpCapture}/bin/devcoredump-capture %i";

      # Run as root: reading /sys/class/devcoredump/*/data and writing
      # the consume marker both require root privileges.
      User = "root";
      Group = "root";

      # Sandboxing. The unit needs to read sysfs (devcoredump entries
      # plus failing_device symlinks into /sys/devices), read the
      # journal, and write compressed artefacts under
      # /var/lib/devcoredump. Everything else can be locked down.
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        "/var/lib/devcoredump"
        "/sys/class/devcoredump"
      ];
      PrivateTmp = true;
      PrivateNetwork = true;
      ProtectKernelTunables = false; # writes to sysfs data attribute
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];
      CapabilityBoundingSet = [ "" ];
      AmbientCapabilities = [ "" ];

      # A capture should complete well within a minute even for large
      # dumps; cap the runtime to avoid wedging the unit on a stuck
      # sysfs read.
      TimeoutStartSec = "120s";
    };
  };
}
