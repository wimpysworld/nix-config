# Console Mixin

Console, locale, font, timezone, and KMSCON configuration for all NixOS hosts.

## What This Module Does

- Configures KMSCON as the system console on all VTs (replacing `agetty`)
- Applies Catppuccin Mocha palette to both KMSCON and the Linux VT (kernel params)
- Sets locale to `en_GB.UTF-8` with UK keyboard layout
- Configures per-host font sizes for KMSCON
- Enables auto-login on ISO images (`autologinUser = "nixos"`)
- Provides geolocation-based timezone on workstations (via geoclue2)

## Custom Packages

This module uses custom builds of kmscon and libtsm, not the nixpkgs versions:

| Package | Version | Source | Path |
|---------|---------|--------|------|
| kmscon | 9.3.2 | [kmscon/kmscon](https://github.com/kmscon/kmscon) | `pkgs/kmscon/default.nix` |
| libtsm | 4.4.2 | [kmscon/libtsm](https://github.com/kmscon/libtsm) | `pkgs/libtsm/default.nix` |

The custom kmscon package includes a `postPatch` that redirects the systemd unit install directory from the read-only `systemd-libs` store path to the package's own output. This ensures the shipped `kmsconvt@.service` unit file is accessible.

## KMSCON Configuration

The NixOS `services.kmscon` module is used as the base, with these settings:

- `hwRender = false` - fbdev backend (reinforced by `no-drm` in `extraConfig`)
- `useXkbConfig = true` - bakes XKB settings into the kmscon config file
- Font: FiraCode Nerd Font Mono (via `nerd-fonts.fira-mono`)
- `no-switchvt` - prevents kmscon from capturing VT switch keys
- `sb-size=16384` - scrollback buffer size
- `palette=custom` - full Catppuccin Mocha colour map

Per-host font sizes are defined in `kmsconFontSize` (defaults to 16 if not listed).

---

## KMSCON Bug Report: Blank Screen on VT1 at Boot

**This section documents two interacting bugs in the NixOS kmscon module that cause a blank screen on VT1 at boot. It is written to support filing an upstream bug report against nixpkgs.**

### Symptom

When KMSCON is enabled via `services.kmscon`, VT1 is blank at boot. No login prompt appears. Switching away from VT1 (Ctrl+Alt+F2) and back (Ctrl+Alt+F1) causes the console to render correctly. This is particularly visible on ISO images where auto-login is expected.

### Environment

- NixOS with `services.kmscon.enable = true`
- kmscon 9.3.2 from [kmscon/kmscon](https://github.com/kmscon/kmscon) fork
- libtsm 4.4.2 from [kmscon/libtsm](https://github.com/kmscon/libtsm)
- `hwRender = false` (fbdev backend)
- Tested on multiple x86_64-linux hosts

### Root Cause

Two independent problems interact to produce this behaviour.

#### Problem A: The `autovt@` alias is reactive-only

The NixOS kmscon module ([`nixos/modules/services/ttys/kmscon.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/ttys/kmscon.nix)) registers `kmsconvt@.service` with `aliases = [ "autovt@.service" ]`. This tells systemd-logind to spawn `kmsconvt@` instead of `getty@` when a user *switches to* a VT.

However, `autovt@.service` is only triggered **reactively** by systemd-logind in response to a VT switch event. It is not proactively started at boot.

On a standard NixOS system without kmscon, `getty@tty1.service` has `WantedBy=getty.target` in its `[Install]` section, ensuring VT1 gets a login prompt at boot. The kmscon module replaces getty via the alias mechanism but never adds equivalent proactive activation for VT1.

The upstream kmscon package's shipped systemd unit ([`kmsconvt@.service`](https://github.com/kmscon/kmscon/blob/main/scripts/systemd/kmsconvt%40.service)) does declare `WantedBy=getty.target` in its `[Install]` section, and the NixOS module loads it via `systemd.packages`. However, the module also overrides the service extensively, and the alias-based mechanism takes precedence in practice - the `WantedBy` from the shipped unit is never materialised into a symlink for a concrete instance.

**Result:** No kmscon instance starts on VT1 at boot. VT1 remains blank until a user manually switches VTs, which triggers logind's reactive `autovt@` mechanism.

#### Problem B: NixOS `wantedBy` on template units creates unusable symlinks

The natural fix for Problem A would be to add `wantedBy = [ "getty.target" ]` to `systemd.services."kmsconvt@"`. This does not work.

NixOS's `generateUnits` function (in `nixos/lib/systemd-lib.nix`) creates `.wants` symlinks mechanically from the `wantedBy` list. For a template unit `kmsconvt@.service`, it produces:

```
getty.target.wants/kmsconvt@.service
```

This is a bare template name. systemd ignores bare template symlinks in `.wants` directories because it cannot determine which instance to start. Compare with `systemctl enable`, which reads the `[Install]` section, finds `DefaultInstance=`, and creates a properly instantiated symlink such as:

```
getty.target.wants/kmsconvt@tty1.service
```

NixOS has no equivalent logic for `DefaultInstance`. This is a known limitation documented across multiple nixpkgs issues:

- [#108054](https://github.com/NixOS/nixpkgs/issues/108054) - NixOS doesn't handle `DefaultInstance` for template units
- [#108643](https://github.com/NixOS/nixpkgs/issues/108643) - Related template unit symlink issue
- [#80933](https://github.com/NixOS/nixpkgs/issues/80933) - Related template unit symlink issue

**Result:** Even if `wantedBy` is added to the template, the generated symlink is unusable and systemd silently ignores it.

### Fix Applied

Two changes are applied in this module to work around both problems.

#### Fix A: Template-level service overrides

Override `systemd.services."kmsconvt@"` to add proper boot ordering, getty conflict handling, and a fallback:

```nix
systemd.services."kmsconvt@" = {
  after = [
    "systemd-user-sessions.service"
    "plymouth-quit-wait.service"
    "getty-pre.target"
    "dbus.service"
    "systemd-localed.service"
  ];
  before = [ "getty.target" ];
  conflicts = [ "getty@%i.service" ];
  onFailure = [ "getty@%i.service" ];
  unitConfig = {
    IgnoreOnIsolate = true;
    ConditionPathExists = "/dev/tty0";
  };
  serviceConfig = {
    Type = "idle";
  };
};
```

Key properties:

| Property | Purpose |
|----------|---------|
| `after` (user-sessions, plymouth, getty-pre) | Delays start until boot is ready for interactive sessions |
| `after` (dbus, systemd-localed) | Ensures D-Bus is available for keyboard layout queries (see Bug 2 below) |
| `before = [ "getty.target" ]` | Ensures kmscon is started before getty.target is reached |
| `conflicts = [ "getty@%i.service" ]` | Prevents both kmscon and getty running on the same VT |
| `onFailure = [ "getty@%i.service" ]` | Falls back to getty if kmscon crashes |
| `Type = "idle"` | Delays kmscon start until all active boot jobs complete |
| `ConditionPathExists = "/dev/tty0"` | Skips activation in containers or systems without a real VT subsystem |
| `IgnoreOnIsolate = true` | Survives target isolation transitions (e.g. `rescue.target`) |

#### Fix B: Explicit VT1 instance activation

Bypass the template `wantedBy` limitation by setting `wantedBy` on a concrete instance:

```nix
systemd.services."kmsconvt@tty1".wantedBy = [ "getty.target" ];
```

This creates the correct symlink:

```
getty.target.wants/kmsconvt@tty1.service -> ../kmsconvt@.service
```

systemd can resolve this to a concrete instance and starts `kmsconvt@tty1` proactively at boot. VTs 2 and above continue to be handled reactively by logind via the `autovt@` alias when the user switches to them.

### Bug 2: Keyboard Layout Requires D-Bus at Runtime

The installed `kmscon` binary at `$prefix/bin/kmscon` is a shell wrapper generated from [`scripts/kmscon.in`](https://github.com/kmscon/kmscon/blob/main/scripts/kmscon.in) by the meson build system. The real C binary lives at `$prefix/libexec/kmscon/kmscon`.

The wrapper includes a `setupLocale()` function that:

1. Checks whether `XKB_DEFAULT_*` environment variables are already set
2. If not, uses `dbus-send` to query `org.freedesktop.locale1` (systemd-localed) over the system D-Bus
3. Falls back to `localectl status` (which also uses D-Bus internally)
4. Exports `XKB_DEFAULT_LAYOUT`, `XKB_DEFAULT_MODEL`, `XKB_DEFAULT_VARIANT`, `XKB_DEFAULT_OPTIONS`

Although the NixOS module's `useXkbConfig = true` bakes XKB settings into the kmscon config file at build time, the wrapper script's `setupLocale()` still runs and queries D-Bus before the config file is parsed. Without `dbus.service` and `systemd-localed.service` available, the D-Bus query may fail or return incomplete results.

**Fix:** The `after` list in Fix A already includes `dbus.service` and `systemd-localed.service`, ensuring both are running before any kmscon instance starts.

### Upstream References

| Reference | Link |
|-----------|------|
| nixpkgs issue #327638 - kmscon frozen display / blank VT1 | https://github.com/NixOS/nixpkgs/issues/327638 |
| nixpkgs issue #385497 - kmscon service ordering | https://github.com/NixOS/nixpkgs/issues/385497 |
| nixpkgs PR #391574 - Proposed rewrite of NixOS kmscon module | https://github.com/NixOS/nixpkgs/pull/391574 |
| nixpkgs PR #489469 - Successor to #391574 | https://github.com/NixOS/nixpkgs/pull/489469 |
| nixpkgs PR #383631 - kmscon + libtsm version bump | https://github.com/NixOS/nixpkgs/pull/383631 |
| nixpkgs issue #108054 - DefaultInstance not handled for template units | https://github.com/NixOS/nixpkgs/issues/108054 |
| nixpkgs issue #108643 - Template unit symlink issue | https://github.com/NixOS/nixpkgs/issues/108643 |
| nixpkgs issue #80933 - Template unit symlink issue | https://github.com/NixOS/nixpkgs/issues/80933 |
| kmscon upstream systemd unit | https://github.com/kmscon/kmscon/blob/main/scripts/systemd/kmsconvt%40.service |
| kmscon wrapper script (kmscon.in) | https://github.com/kmscon/kmscon/blob/main/scripts/kmscon.in |

### Cross-reference: Noughty Linux

The fixes were informed by the [Noughty Linux project](https://github.com/noughtylinux/config/blob/main/system-manager/kmscon.nix), which solved the same problems by:

- Creating explicit per-VT services (`kmsconvt@tty1` through `kmsconvt@tty8`) each with `wantedBy = [ "getty.target" ]`
- Using `Type = idle` for delayed start
- Including `dbus.service` and `systemd-localed.service` in `after`
- Using the Aetf fork of kmscon with an `auto-kbd-layout.patch`

Noughty Linux does not use the NixOS `services.kmscon` module at all - it defines everything from scratch via `systemd.services`. The approach in this module is lighter: use the NixOS module as the base and override the systemd service to fix the activation and ordering issues.

### Summary for Upstream

The NixOS kmscon module (`nixos/modules/services/ttys/kmscon.nix`) has two defects that combine to produce a blank VT1 at boot:

1. **Missing proactive VT1 activation.** The `autovt@` alias only triggers reactively on VT switch. No mechanism starts kmscon on VT1 at boot. The module should either create an explicit `kmsconvt@tty1` instance with `wantedBy = [ "getty.target" ]`, or the NixOS systemd unit generator should learn to resolve `DefaultInstance` when creating `.wants` symlinks for template units.

2. **Missing service ordering.** The kmscon wrapper script queries D-Bus for keyboard layout information at startup. Without `after` dependencies on `dbus.service` and `systemd-localed.service`, this query may fail. The template service also lacks proper ordering relative to `systemd-user-sessions.service`, `plymouth-quit-wait.service`, and `getty-pre.target`, and has no `conflicts` or `onFailure` relationship with `getty@%i.service`.

Both issues are fixable within the existing module. PRs [#391574](https://github.com/NixOS/nixpkgs/pull/391574) and [#489469](https://github.com/NixOS/nixpkgs/pull/489469) propose broader rewrites that would address these problems.
