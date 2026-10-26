# OpenUsage

Developer workstations receive the dashboard, a native telemetry service, and a default theme. Servers and users without the `developer` tag receive none.

Home Manager owns `~/.config/systemd/user/openusage-telemetry.service` on Linux and `~/Library/LaunchAgents/com.openusage.telemetryd.plist` on macOS. Both services run `openusage telemetry daemon run` from the same pinned package as the dashboard. Linux uses the existing `sd-switch` policy and `default.target`, without a graphical session dependency. The launchd agent starts at login and restarts after a crash.

The dashboard and service use `config.xdg.stateHome` through `XDG_STATE_HOME`. The daemon creates its database, socket, and spool under the `openusage` subdirectory. Home Manager creates that directory on macOS before launchd opens `daemon.stdout.log` and `daemon.stderr.log`. Linux sends service output to the journal.

Home Manager owns the whole `~/.config/openusage/settings.json` file and sets its top-level `theme` to the built-in `Catppuccin Mocha`. OpenUsage uses this settings path on both platforms, regardless of `XDG_CONFIG_HOME`. The managed file is read-only, so interactive settings changes cannot persist. No custom palette or font settings are required.

Before activation, migrate existing non-secret settings into this Nix declaration or retain the backup that the usual `just switch-home` creates. Home Manager keeps its normal collision checks and backup flow for settings and service definitions. On Linux, it forcibly replaces only `~/.config/systemd/user/default.target.wants/openusage-telemetry.service`, because the upstream enablement symlink is not eligible for backup. Existing settings are not merged automatically. Never put credentials in this declaration, because the generated file enters the Nix store.

A compatible daemon serves dashboard requests without service installation. If the daemon is unreachable, OpenUsage starts or reloads the existing service definition. A reachable, incompatible daemon can trigger upstream service installation.

Close all OpenUsage dashboards before an upgrade or rollback. Reopen them after Home Manager replaces the service. This prevents the dashboard from replacing the managed definition during a version mismatch. Do not run upstream service install or uninstall commands for this configuration.
