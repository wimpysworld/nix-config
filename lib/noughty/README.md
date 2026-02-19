# Noughty: Centralised System Attributes Module

**Status:** Proposal
**Date:** 2026-02-18

**Start here:** Read this document, then `lib/helpers.nix`. Implementation begins at Phase 0 - it is additive with no breakage risk.

## Problem Statement

The nix-config repository threads 15+ values through `specialArgs`/`extraSpecialArgs` to every module across NixOS, nix-darwin, and Home Manager. This is the wrong mechanism. `specialArgs` exists to bootstrap module evaluation when you cannot use the module system itself - typically for passing `inputs` and `outputs`. Using it to distribute computed configuration like `isLaptop`, `isWorkstation`, `tailNet`, and `username` bypasses the NixOS module system's type checking, documentation, overridability, and composition guarantees.

### Concrete costs today

1. **Triplicated logic.** The boolean flags `isISO`, `isLaptop`, `isLima`, `isWorkstation`, and `isServer` are computed identically in `mkHome` and `mkNixos`, and hardcoded differently in `mkDarwin`. Every new flag requires editing three functions in `lib/helpers.nix` and updating three `specialArgs`/`extraSpecialArgs` blocks.

2. **Fragile negative lists.** `isLaptop` is defined as `hostname != "vader" && hostname != "phasma" && hostname != "revan" && hostname != "malak" && hostname != "maul"`. Adding a new desktop server means remembering to update this list. Forgetting silently enables laptop power management on a desktop workstation.

3. **Inconsistent flag availability.** `tailNet` exists only in `mkNixos` `specialArgs`. If a Home Manager module ever needs it, there is no path to access it. `isLima` is not in `mkDarwin`. Modules cannot rely on a consistent set of attributes.

4. **Ad-hoc gating patterns.** At least four distinct patterns are used across 90+ files:
   - `installFor = ["martin"]; lib.mkIf (lib.elem username installFor)` - 30+ files, each independently defining user lists.
   - `installOn = ["phasma" "vader"]; lib.mkIf (lib.elem hostname installOn)` - 15+ files, each independently defining host lists.
   - `hostname == "phasma" || hostname == "vader"` - 50+ occurrences, often with local aliases like `isStreamstation` or `isThinkpad` that duplicate host knowledge scattered across the tree.
   - `isServer = hostname == "revan" || hostname == "malak" || hostname == "maul"` - redefined locally in `nixos/_mixins/network/default.nix`, shadowing the identically-named `specialArgs` value.

5. **No type safety.** Nothing prevents a mixin from misspelling `isWorkstaion` in its function arguments. It silently receives `null` rather than raising an error, because `specialArgs` values are untyped.

6. **No overridability.** A host-specific module cannot say "actually, this host should be treated as a laptop even though the central logic disagrees." `specialArgs` values are immutable once set.


## Proposed Solution

Introduce a local NixOS-style options module under a `noughty` namespace. This module:

- Declares typed options for all system attributes currently passed via `specialArgs`.
- Is imported into all three module systems (NixOS, nix-darwin, Home Manager).
- Has its option values set once by `mkNixos`/`mkDarwin`/`mkHome` from the system registry.
- Provides convenience helper functions via `noughtyLib`, injected as a module argument via `_module.args`.
- Allows per-host overrides via the standard `lib.mkForce` mechanism.

### Why a module, not just better helpers.nix?

The NixOS module system provides type checking, default values, `mkDefault`/`mkForce` overridability, option documentation, and the ability for downstream modules to read values without function argument threading. A `noughty` module leverages all of this. Helper functions in `lib/` cannot.


## Module Structure

### File layout

```
lib/
  noughty/
    default.nix          # Option declarations, derived defaults, _module.args.noughtyLib setter
  noughty-helpers.nix    # Pure helper functions (no module system dependency)
```

The module is imported once in each entry point:
- `nixos/default.nix` imports `../lib/noughty` and populates `noughty.*` values from `specialArgs`
- `darwin/default.nix` imports `../lib/noughty` and populates `noughty.*` values from `specialArgs`
- `home-manager/default.nix` imports `../lib/noughty` and populates `noughty.*` values from `extraSpecialArgs`

**Rule: the shared module declares and derives; the entry points populate.**

`lib/noughty/default.nix` contains only option declarations, derived boolean defaults, and the `_module.args.noughtyLib` setter. It uses only `lib`, `options`, and `config` - the portable subset of the module system - making it safe to import verbatim into all three module system contexts without per-system wrapper files.

The pure helper functions live in `lib/noughty-helpers.nix` as a plain Nix function, called from the `_module.args.noughtyLib` setter. This keeps the helper logic independently testable and free of module system entanglement.

The module uses `lib.mkDefault` for all computed values, so any host-specific module can override them with `lib.mkForce`.


## Helper Function Delivery: `_module.args`

Helper functions are delivered via `_module.args.noughtyLib`, not as module options. This makes `noughtyLib` available as a named argument in any module, exactly like `lib` or `pkgs`:

```nix
{ lib, noughtyLib, ... }:
{
  programs.foo.enable = lib.mkIf (noughtyLib.onHosts [ "vader" "phasma" ]) true;
}
```

The setter in `lib/noughty/default.nix`:

```nix
{ config, lib, ... }:
let
  helpers = import ../noughty-helpers.nix { inherit lib; };
in
{
  _module.args.noughtyLib = helpers {
    hostName = config.noughty.host.name;
    userName = config.noughty.user.name;
    hostTags = config.noughty.host.tags;
    userTags = config.noughty.user.tags;
  };
}
```

**Why `_module.args` mitigates infinite recursion:** `_module.args` is populated after the module system begins evaluation. The functions it contains close over `config.noughty.*` values lazily - they are only evaluated when a downstream module actually calls `noughtyLib.onHosts [...]`, by which point `noughty.host.name` is already fixed. The recursion risk that exists when defining functions inside option `config` blocks is absent here because `_module.args` assignments are not part of the option-tree construction itself.


## Option Declarations

### `noughty.host` - Host identity and classification

| Option | Type | Description |
|--------|------|-------------|
| `noughty.host.name` | `str` | Hostname. Replaces `hostname` specialArg in module bodies. |
| `noughty.host.kind` | `enum ["computer" "server" "vm" "container"]` | Class of host system, independent of OS or use-case. Replaces the overloaded registry `type` within the module system. |
| `noughty.host.platform` | `str` | Architecture string, e.g. `"x86_64-linux"` or `"aarch64-darwin"`. |
| `noughty.host.desktop` | `nullOr str` | Desktop environment name or `null`. |
| `noughty.host.os` | `enum ["linux" "darwin"]` | OS of the managed system, derived from `platform`. Read-only. |
| `noughty.host.formFactor` | `nullOr (enum ["laptop" "desktop" "handheld" "tablet" "phone"])` | Physical form factor. `null` for virtual or headless systems. |
| `noughty.host.tags` | `listOf str` | Freeform tags for host classification. See [Tags](#tags-replacing-ad-hoc-hostname-lists) below. |

#### Notes on `noughty.host.kind`

`kind` describes *what class of system this is*, independent of OS, use-case, or deployment mechanism. The values map from the former registry `type` as follows:

| Former registry `type` | `noughty.host.kind` | Notes |
|---|---|---|
| `workstation` | `computer` | Desktop or laptop physical system |
| `gaming` / `steamdeck` | `computer` | Use-case, not a system class; use tag `"steamdeck"` |
| `darwin` | `computer` | OS, not a system class; `noughty.host.os` captures this |
| `server` | `server` | Unchanged |
| `vm` | `vm` | Generic virtual machine |
| `lima` | `vm` | Lima is a VM implementation detail; use tag `"lima"` |
| `wsl` | `vm` | WSL is a VM implementation detail; use tag `"wsl"` |
| `iso` | *(not applicable)* | ISO is a deployment medium, not a persistent system class; covered by `is.iso` boolean and the registry `iso = true` field |

`container` is added to `kind` in anticipation of NixOS container and OCI image configurations, which are realistic future system classes.

#### Notes on `noughty.host.os`

`os` is always derived from `platform` and is never set manually:

```nix
noughty.host.os = lib.mkOption {
  type = lib.types.enum [ "linux" "darwin" ];
  default = lib.mkDefault (
    if lib.hasSuffix "-linux" config.noughty.host.platform then "linux" else "darwin"
  );
  description = "OS of the managed system, derived from platform. Never set this manually.";
  readOnly = true;
};
```

`os` reflects the *managed* system, not the underlying host. A WSL host manages a Linux system, so `os = "linux"`. A Lima host manages a Linux system, so `os = "linux"`. This is consistent with everything else in `noughty.*`, which describes the system being configured.

Deriving from `platform` (not `pkgs.stdenv`) avoids a `pkgs` dependency in the module declarations and keeps the shared file evaluable in all three module system contexts.

#### Notes on `noughty.host.formFactor`

`formFactor` is `null` for servers, VMs, WSL, ISO, and any system without a physical chassis. Values:

| Value | Current use |
|---|---|
| `"laptop"` | Battery-powered portables; drives power management config |
| `"desktop"` | Mains-powered fixed systems; absence of laptop config |
| `"handheld"` | Steam Deck and similar |
| `"tablet"` | Tablet form factor |
| `"phone"` | Phone form factor |

### `noughty.host.is` - Derived boolean flags

All derived from `noughty.host.kind`, `noughty.host.os`, `noughty.host.desktop`, and `noughty.host.formFactor`. Each uses `lib.mkDefault` so host-specific modules can override with `lib.mkForce`.

| Option | Type | Default derivation | Replaces |
|--------|------|--------------------|----------|
| `noughty.host.is.workstation` | `bool` | `desktop != null` | `isWorkstation` specialArg |
| `noughty.host.is.server` | `bool` | `kind == "server"` | `isServer` specialArg |
| `noughty.host.is.laptop` | `bool` | `formFactor == "laptop"` | `isLaptop` specialArg |
| `noughty.host.is.iso` | `bool` | registry `iso == true` (set at entry point) | `isISO` specialArg |
| `noughty.host.is.vm` | `bool` | `kind == "vm"` | ad-hoc checks |
| `noughty.host.is.darwin` | `bool` | `os == "darwin"` | ad-hoc `pkgs.stdenv.isDarwin` checks |
| `noughty.host.is.linux` | `bool` | `os == "linux"` | ad-hoc `pkgs.stdenv.isLinux` checks |

📌 **`isLaptop` fix:** Derived cleanly from `formFactor == "laptop"`. No negative hostname list, no tag discipline required. Adding a new laptop to the registry just requires setting `formFactor = "laptop"` in the system entry. Adding a new desktop requires nothing - `formFactor = "desktop"` (or `null`) means `is.laptop` is `false` automatically.

📌 **Removed flags:** `is.install`, `is.lima`, `is.wsl`, and `is.gaming` are removed. `is.install` was a redundant negation of `is.iso` - use `!config.noughty.host.is.iso` directly. Lima and WSL hosts use `kind = "vm"` with tags `"lima"` and `"wsl"` respectively. The Steam Deck uses `kind = "computer"` with tag `"steamdeck"`. Use `noughtyLib.hostHasTag "lima"` etc. for conditional config.

### `noughty.user` - User identity

| Option | Type | Description |
|--------|------|-------------|
| `noughty.user.name` | `str` | Primary username. Replaces `username` specialArg in module bodies. |
| `noughty.user.tags` | `listOf str` | Freeform tags for user role/persona classification. See [Tags](#tags-replacing-ad-hoc-hostname-lists) below. |

### `noughty.host.gpu` - GPU vendor classification

| Option | Type | Description |
|--------|------|-------------|
| `noughty.host.gpu.vendors` | `listOf (enum ["nvidia" "amd" "intel"])` | GPU vendors present in this host. Empty list means no discrete or relevant GPU. Set in the registry. |

#### Derived GPU booleans

All read-only, derived from `gpu.vendors`:

| Option | Type | Default derivation | Replaces |
|--------|------|--------------------|----------|
| `noughty.host.gpu.hasNvidia` | `bool` | `elem "nvidia" vendors` | `lib.elem "nvidia" config.services.xserver.videoDrivers` (3 files) |
| `noughty.host.gpu.hasAmd` | `bool` | `elem "amd" vendors` | `config.hardware.amdgpu.initrd.enable` |
| `noughty.host.gpu.hasIntel` | `bool` | `elem "intel" vendors` | Kernel module scanning for `i915`/`xe` |
| `noughty.host.gpu.hasAny` | `bool` | `vendors != []` | ad-hoc `hostHasTag "gpu"` checks |
| `noughty.host.gpu.hasCuda` | `bool` | `elem "nvidia" vendors` | Hostname enumeration in ollama `accelerationMap` |

#### Why structured options, not tags

A bare `hostHasTag "gpu"` cannot distinguish vendors. The codebase branches on nvidia/amd/intel independently across five NixOS modules, and hosts like vader have both AMD and NVIDIA GPUs. Using tags would require `hostHasTag "nvidia"` and `hostHasTag "amd"` - tags doing the job of an enum list, but without type validation or derived helpers. Misspelling `"nvida"` in a tag fails silently; misspelling it in an enum produces an immediate evaluation error.

#### What GPU options do NOT cover

Per-host hardware config (PCI bus IDs, PRIME setup, kernel modules, `nixos-hardware` imports) stays in host directories. `gpu.vendors` captures *which vendors are present* - the classification question. The hardware plumbing remains where it belongs.

#### Current duplication eliminated

The expression `hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers` is defined independently in three files (`nixos/_mixins/hardware/gpu/`, `nixos/_mixins/virtualisation/`, `nixos/_mixins/server/netdata/`). The ollama module uses a hardcoded hostname-to-acceleration map (`{ maul = "cuda"; phasma = "cuda"; vader = "cuda"; }`). All four are replaced by `config.noughty.host.gpu.hasNvidia` / `config.noughty.host.gpu.hasCuda`.

### `noughty.host.displays` - Display output configuration

A list of display submodules, each describing one physical output. Set in host-specific modules (not the registry - display data is too verbose for the registry and tightly coupled to hardware config that already lives in host directories).

```nix
noughty.host.displays = lib.mkOption {
  type = lib.types.listOf (lib.types.submodule {
    options = {
      output     = lib.mkOption { type = lib.types.str; };                           # "DP-1", "eDP-1"
      width      = lib.mkOption { type = lib.types.int; };                           # 3440
      height     = lib.mkOption { type = lib.types.int; };                           # 1440
      refresh    = lib.mkOption { type = lib.types.int; default = 60; };             # 100
      scale      = lib.mkOption { type = lib.types.float; default = 1.0; };          # 1.25
      position   = lib.mkOption {
        type = lib.types.submodule {
          options = {
            x = lib.mkOption { type = lib.types.int; default = 0; };
            y = lib.mkOption { type = lib.types.int; default = 0; };
          };
        };
        default = { x = 0; y = 0; };
      };
      primary    = lib.mkOption { type = lib.types.bool; default = false; };
      workspaces = lib.mkOption { type = lib.types.listOf lib.types.int; default = []; };
    };
  });
  default = [];
  description = "Physical display outputs. Set in host-specific modules.";
};
```

#### Example: vader (3 displays)

```nix
# nixos/vader/default.nix (or home-manager equivalent)
noughty.host.displays = [
  { output = "DP-1"; width = 2560; height = 2880; primary = true; workspaces = [ 1 2 7 8 9 ]; }
  { output = "DP-2"; width = 2560; height = 2880; workspaces = [ 3 4 5 6 ]; }
  { output = "DP-3"; width = 1920; height = 1080; workspaces = [ 10 ]; }
];
```

#### Example: tanis (single laptop display)

```nix
# nixos/tanis/default.nix
noughty.host.displays = [
  { output = "eDP-1"; width = 1920; height = 1200; primary = true; workspaces = [ 1 2 3 4 5 6 7 8 ]; }
];
```

#### Derived display values

All read-only, derived from `noughty.host.displays`:

| Option | Type | Derivation | Purpose |
|--------|------|------------|---------|
| `noughty.host.display.primary` | `submodule` | First display where `primary == true`, or first in list | The primary display attrset |
| `noughty.host.display.primaryOutput` | `str` | `primary.output` | Shortcut: `"DP-1"` |
| `noughty.host.display.primaryWidth` | `int` | `primary.width` | Shortcut: `3440` |
| `noughty.host.display.primaryHeight` | `int` | `primary.height` | Shortcut: `1440` |
| `noughty.host.display.primaryResolution` | `str` | `"${width}x${height}"` | Formatted: `"3440x1440"` |
| `noughty.host.display.isMultiMonitor` | `bool` | `length displays > 1` | Multi-monitor layout decisions |
| `noughty.host.display.outputs` | `listOf str` | `map (d: d.output) displays` | All output names: `["DP-1" "DP-2" "DP-3"]` |

#### Why `displays` lives in host modules, not the registry

Display data includes output names, positions, workspace assignments, and refresh rates - too verbose and hardware-specific for the system registry in `flake.nix`. The registry captures classification (kind, formFactor, tags); display config is hardware fact that belongs alongside kernel modules and PCI bus IDs in host directories. The module system merges values from wherever they are set, so consumers don't care about the source.

#### Current duplication eliminated

The same display data (output names, resolutions, refresh rates) is currently duplicated across **9 files** in at least 3 different formats: Hyprland monitor strings, kanshi config, kernel `video=` params, wallpaper filenames, lock screen sizing, and status bar output targeting. Vader's display data alone appears in 7 files. With `noughty.host.displays`, all consumers derive from one declaration:

| Consumer | Currently | After |
|----------|-----------|-------|
| `monitors.nix` | Hostname-keyed attrset with Hyprland strings | Generate from `displays` list |
| `hyprpaper/` | `if hostname ==` chains for output→wallpaper | Map over `displays`, select wallpaper by resolution |
| `hyprlock/` | `if hostname ==` for primary output and width | `display.primaryOutput`, `display.primaryWidth` |
| `waybar/` | `if hostname ==` for primary output | `display.primaryOutput` |
| `greetd.nix` | Hostname-keyed wallpaper resolutions and kanshi profiles | `display.primaryResolution`, generate kanshi from `displays` |
| `fuzzel/` | `if hostname ==` for font size | Derive from `display.primaryWidth` |
| Kernel `video=` params | Hardcoded in host dirs | `map (d: "video=${d.output}:${toString d.width}x${toString d.height}@${toString d.refresh}") displays` |

### `noughty.network` - Network attributes

| Option | Type | Description |
|--------|------|-------------|
| `noughty.network.tailNet` | `str` | Tailscale network domain. Currently only in `mkNixos`; now available everywhere. Default: `"drongo-gamma.ts.net"`. |


## Tags: Replacing Ad-hoc Hostname Lists

📌 **Key design decision.** `noughty.host.tags` and `noughty.user.tags` absorb the scattered hostname and username lists that currently live inside individual mixins.

### Two tag lists

There are two distinct tag lists, each serving a different classification axis:

- **`noughty.host.tags`** - hardware capabilities and role of the host system (e.g., `"streamstation"`, `"thinkpad"`)
- **`noughty.user.tags`** - role or persona of the primary user (e.g., `"developer"`, `"admin"`, `"family"`)

This separation exists because installed software and configuration may depend on either the host's hardware and peripherals, or the user's role and persona, or both. A module that installs professional audio tooling might gate on `userHasTag "audio-producer"`. A module that configures GPU compute gates on `config.noughty.host.gpu.hasCuda` (see [GPU vendor classification](#noughtyHostgpu---gpu-vendor-classification)). Keeping the two lists separate makes the intent of each check unambiguous.

### What tags solve

Today, multiple files independently encode knowledge like "phasma and vader are stream workstations" or "tanis, sidious, shaa, and atrius are ThinkPads":

```nix
# nixos/_mixins/hardware/streamdeck/default.nix
isStreamstation = hostname == "phasma" || hostname == "vader";

# nixos/_mixins/hardware/power-management/default.nix
isThinkpad = hostname == "tanis" || hostname == "sidious" || hostname == "shaa" || hostname == "atrius";

# nixos/_mixins/hardware/audio/default.nix
useLowLatencyPipewire = hostname == "phasma" || hostname == "vader";
```

Adding a new streaming workstation means finding and updating every file that checks for this. Tags centralise this knowledge in the registry.

### How tags are set

**Host tags** are set in the system registry for tags that define the host's nature:

```nix
systems = {
  vader = {
    kind        = "computer";
    platform    = "x86_64-linux";
    formFactor  = "desktop";
    gpu.vendors = [ "amd" "nvidia" ];
    tags        = [ "streamstation" "high-dpi" ];
  };
  tanis = {
    kind       = "computer";
    platform   = "x86_64-linux";
    formFactor = "laptop";
    tags       = [ "thinkpad" ];
  };
  malak = {
    kind     = "server";
    platform = "x86_64-linux";
  };
};
```

Additional host tags for hardware details better co-located with hardware config can be set in host-specific modules:

```nix
# nixos/vader/default.nix
noughty.host.tags = [ "nvme" "dual-monitor" ];
```

Because `tags` is `listOf str`, values from the registry and host modules merge automatically via the module system.

**User tags** are set in user-specific Home Manager modules or the Home Manager entry point:

```nix
# home-manager/martin/default.nix
noughty.user.tags = [ "developer" "admin" ];
```

### How tags are consumed

Mixins use `noughtyLib.hostHasTag`, `noughtyLib.userHasTag`, or the other tag helpers. See [Complete Helper Function Reference](#complete-helper-function-reference).

```nix
# Before (scattered hostname checks):
isStreamstation = hostname == "phasma" || hostname == "vader";
systemd.user.services.deckmaster-xl = lib.mkIf isStreamstation { ... };

# After (centralised tag):
{ noughtyLib, lib, ... }:
{
  systemd.user.services.deckmaster-xl = lib.mkIf (noughtyLib.hostHasTag "streamstation") { ... };
}
```

### Canonical tag vocabulary

Tags are freeform `listOf str`. The canonical vocabulary is documented in a comment block in the registry section of `flake.nix`. This is the single source of truth for tag names. Typos produce silent misconfiguration (the same failure mode being solved for booleans), so documentation discipline matters. See [Trade-offs](#trade-offs-and-limitations) for the validation discussion.

⚠️ **Tags are not a replacement for everything.** Per-host display resolution, hwmon paths, and wallpaper selections are genuinely host-specific values that belong in host modules, not tags. Tags are for *classification* ("this host is a streamstation"), not *configuration* ("this host uses DP-1").


## Convenience Helpers: Before and After

### Pattern 1: User-gated module (most common, ~30 files)

**Before:**
```nix
{ username, lib, pkgs, ... }:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  home.packages = [ pkgs.zed-editor ];
}
```

**After:**
```nix
{ noughtyLib, lib, pkgs, ... }:
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home.packages = [ pkgs.zed-editor ];
}
```

`noughtyLib` closes over `config.noughty.user.name`. The module no longer needs `username` in its argument list.

### Pattern 2: Host-gated module (~15 files)

**Before:**
```nix
{ hostname, lib, pkgs, ... }:
let
  installOn = [ "phasma" "vader" ];
  shellApplication = pkgs.writeShellApplication { ... };
in
lib.mkIf (builtins.elem hostname installOn) { home.packages = [ shellApplication ]; }
```

**After:**
```nix
{ noughtyLib, lib, pkgs, ... }:
let
  shellApplication = pkgs.writeShellApplication { ... };
in
lib.mkIf (noughtyLib.isHost [ "phasma" "vader" ]) { home.packages = [ shellApplication ]; }
```

### Pattern 3: Tag-gated module (new, replaces hostname comparisons)

**Before:**
```nix
{ hostname, lib, ... }:
let
  isStreamstation = hostname == "phasma" || hostname == "vader";
in
{
  services.foo = lib.mkIf isStreamstation { ... };
}
```

**After:**
```nix
{ noughtyLib, lib, ... }:
{
  services.foo = lib.mkIf (noughtyLib.hostHasTag "streamstation") { ... };
}
```

### Pattern 4: Boolean flag gating (~200 occurrences)

**Before:**
```nix
{ isISO, isWorkstation, lib, ... }:
{
  environment.systemPackages = lib.optionals (!isISO) [ ... ];
}
```

**After:**
```nix
{ config, lib, ... }:
let
  cfg = config.noughty.host;
in
{
  environment.systemPackages = lib.optionals (!cfg.is.iso) [ ... ];
}
```

⚠️ **Caveat on `imports`.** Using `config` in `imports` creates an infinite recursion because `imports` is evaluated before `config` is fixed. The old `imports = lib.optional isWorkstation ./_mixins/desktop` pattern cannot be translated to `imports = lib.optional cfg.is.workstation ./_mixins/desktop` - this will recurse. Instead, make the import unconditional and have the imported module gate itself internally using the long-form pattern (see [Pattern 9](#pattern-9-long-form-module-with-sub-imports-6-hub-modules)). This constraint affects only the ~6 desktop hub modules.

### Pattern 5: Combined user + flag gating

**Before:**
```nix
{ username, isWorkstation, lib, ... }:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor && isWorkstation) { ... }
```

**After:**
```nix
{ config, noughtyLib, lib, ... }:
lib.mkIf (noughtyLib.isUser [ "martin" ] && config.noughty.host.is.workstation) { ... }
```

### Pattern 6: User-differentiated packages (browsers)

**Before:**
```nix
{ username, isISO, lib, pkgs, ... }:
let
  forFamily = [ "agatha" "louise" ];
  forMartin = [ "martin" ];
in
{
  environment.systemPackages =
    lib.optionals (builtins.elem username forFamily && !isISO) familyPackages
    ++ lib.optionals (builtins.elem username forMartin && !isISO) martinPackages;
}
```

**After:**
```nix
{ config, noughtyLib, lib, pkgs, ... }:
{
  environment.systemPackages =
    lib.optionals (noughtyLib.isUser [ "agatha" "louise" ] && !config.noughty.host.is.iso) familyPackages
    ++ lib.optionals (noughtyLib.isUser [ "martin" ] && !config.noughty.host.is.iso) martinPackages;
}
```

The `!is.iso` guard is kept explicit. Baking hidden conditions into helpers is surprising; callers compose conditions themselves.

### Pattern 7: GPU vendor gating (replaces duplicated detection and hostname maps)

**Before (duplicated in 3 files):**
```nix
{ config, lib, ... }:
let
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
{
  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;
}
```

**Before (hostname enumeration in ollama):**
```nix
{ hostname, ... }:
let
  accelerationMap = { maul = "cuda"; phasma = "cuda"; vader = "cuda"; };
in
{
  services.ollama.acceleration = accelerationMap.${hostname} or null;
}
```

**After (both cases):**
```nix
{ config, lib, ... }:
let
  gpu = config.noughty.host.gpu;
in
{
  hardware.nvidia-container-toolkit.enable = gpu.hasNvidia;
  services.ollama.acceleration = if gpu.hasCuda then "cuda" else null;
}
```

Single source of truth. No hostname lists, no config introspection, no duplicated detection logic.

### Pattern 8: Display-dependent config (replaces hostname chains across 9 files)

**Before (hyprlock - repeated pattern in 6 other files):**
```nix
{ hostname, ... }:
let
  monitor = if hostname == "vader" then "DP-1"
    else if hostname == "phasma" then "DP-1"
    else "eDP-1";
  catResolution = if hostname == "vader" then "2560"
    else if hostname == "phasma" then "3440"
    else "1920";
in
{ ... }
```

**Before (greetd wallpaper resolution):**
```nix
wallpaperResolutions = {
  phasma = "3440x1440"; vader = "2560x2880"; bane = "2560x1600";
  tanis = "1920x1200"; felkor = "1920x1200";
};
resolution = wallpaperResolutions.${hostname} or "1920x1080";
```

**After (both cases):**
```nix
{ config, ... }:
let
  display = config.noughty.host.display;
in
{
  # hyprlock: primary output and resolution
  monitor = display.primaryOutput;            # "DP-1"
  catResolution = toString display.primaryWidth; # "2560"

  # greetd: wallpaper resolution
  resolution = display.primaryResolution;     # "2560x2880"
}
```

Declared once in the host module, consumed everywhere. Adding a new workstation means setting `noughty.host.displays` in one file - no other files need updating.

### Pattern 9: Long-form module with sub-imports (~6 hub modules)

Most modules are leaf modules - they set config values and have no `imports`. These use the flat patterns shown in Patterns 1-8: `lib.mkIf condition { ... }` as the entire module body, clean and minimal.

A small number of **hub modules** import sub-modules and also need to gate their own config. These modules require the long-form pattern because `imports` cannot appear inside `lib.mkIf`.

**Before (conditional import at the parent):**
```nix
# nixos/default.nix
{ isWorkstation, lib, ... }:
{
  imports = lib.optional isWorkstation ./_mixins/desktop;
}

# nixos/_mixins/desktop/default.nix
{ isInstall, lib, pkgs, ... }:
{
  imports = [ ./${desktop} ];
  boot.plymouth.enable = true;
  programs.appimage.enable = isInstall;
}
```

**After (unconditional import, internal gate):**
```nix
# nixos/default.nix - import unconditionally
{
  imports = [ ./_mixins/desktop ];
}

# nixos/_mixins/desktop/default.nix - long-form: imports + gated config
{ config, lib, pkgs, ... }:
{
  imports = [
    ./apps
    ./backgrounds
    ./hyprland
    ./wayfire
  ];
  config = lib.mkIf config.noughty.host.is.workstation {
    boot.plymouth.enable = true;
    programs.appimage.enable = !config.noughty.host.is.iso;
  };
}
```

#### When to use the long-form pattern

📌 **Decision rule: does the module have `imports`?**

- **No `imports`** → use the flat pattern: `lib.mkIf condition { ... }` as the entire module body. This is Patterns 1-8 and covers ~95% of modules.
- **Has `imports`** → use the long-form pattern: `{ imports = [...]; config = lib.mkIf condition { ... }; }`. The `imports` stay unconditional; each imported sub-module gates itself internally.

That's it. One question, one answer.

#### Why `imports` cannot be conditional on `config`

The Nix module system evaluates in two passes. First pass: collect all `imports` to build the complete module tree. Second pass: evaluate `config` by merging all modules. Since `imports` are resolved *before* `config` exists, any expression like `imports = lib.optional config.noughty.host.is.workstation ./foo` creates infinite recursion - it needs `config` to determine imports, but needs imports to determine `config`.

The long-form pattern sidesteps this: `imports` are always unconditional (resolved in pass one), and `config` is gated with `lib.mkIf` (evaluated in pass two). The imported sub-modules are always present in the module tree but contribute nothing when their gate is false.

#### Scope

Only ~6 hub modules in the codebase need this pattern - the desktop entry points that fan out to compositor sub-modules. The ~200 leaf modules migrated in Phase 3 use the flat patterns from Patterns 1-5. Adding a new leaf mixin (the common case) never requires the long-form pattern.

#### With `let` bindings

When a hub module has `let` bindings that depend on `config.noughty.*` values (e.g. reading `desktop` which is `null` on non-workstation systems), place the `let` block inside the `config` gate to avoid evaluation failures:

```nix
{ config, lib, pkgs, ... }:
{
  imports = [ ./hyprland ./wayfire ];
  config = lib.mkIf config.noughty.host.is.workstation (
    let
      desktop = config.noughty.host.desktop;
      # bindings that use desktop safely - only evaluated when gate is true
    in
    {
      # config using those bindings
    }
  );
}
```


## Complete Helper Function Reference

All helpers are accessed as `noughtyLib.<name>` where `noughtyLib` is a module argument injected via `_module.args`. No `config` import required in module argument lists solely for helper access.

| Helper | Signature | Returns | Purpose |
|--------|-----------|---------|---------|
| `isUser` | `[str] -> bool` | `elem userName users` | Raw boolean: current user is in list. |
| `isHost` | `[str] -> bool` | `elem hostName hosts` | Raw boolean: current host is in list. |
| `hostHasTag` | `str -> bool` | `elem tag hostTags` | Check for a single host tag. |
| `userHasTag` | `str -> bool` | `elem tag userTags` | Check for a single user tag. |
| `hostHasTags` | `[str] -> bool` | `all (t: elem t hostTags) ts` | Check that *all* listed host tags are present. |
| `userHasTags` | `[str] -> bool` | `all (t: elem t userTags) ts` | Check that *all* listed user tags are present. |
| `hostHasAnyTag` | `[str] -> bool` | `any (t: elem t hostTags) ts` | Check that *at least one* listed host tag is present. |
| `userHasAnyTag` | `[str] -> bool` | `any (t: elem t userTags) ts` | Check that *at least one* listed user tag is present. |

All closures capture `hostName`, `userName`, `hostTags`, and `userTags` from `config.noughty.*` at evaluation time. Consuming modules need only `noughtyLib` (and `config` when accessing `is.*` flags directly) in their argument lists.


## Interaction with the System Registry

The system registry in `flake.nix` remains the single source of truth. The flow changes as follows:

### Current flow

```
flake.nix registry
  → lib/helpers.nix computes booleans
    → specialArgs threads them to every module
      → modules destructure specialArgs in function heads
```

### Proposed flow

```
flake.nix registry
  → lib/helpers.nix passes registry values as minimal specialArgs
    → entry point (nixos/darwin/home-manager) imports noughty module, sets noughty.* values
      → noughty module computes derived booleans as option defaults
        → modules read config.noughty.* or call noughtyLib helpers
```

### Registry changes

The registry `type` field is **removed entirely**. It is replaced by `kind`, `platform`, `formFactor`, `tags`, and the `iso` boolean. `platform` is now a required field with no default - missing `platform` produces an immediate evaluation error.

Defaults are resolved in `lib/helpers.nix` by `resolveEntry`, which merges four layers in order (later layers win):

```nix
resolveEntry = name: entry:
  let
    isDarwin = lib.hasSuffix "-darwin" entry.platform;

    kDefaults = {
      desktop = {
        computer  = if isDarwin then "aqua" else "hyprland";
        server    = null;
        vm        = null;
        container = null;
      }.${entry.kind};
    };

    isoDefaults = lib.optionalAttrs (entry.iso or false) {
      desktop  = null;
      username = "nixos";
    };
  in
    { username = "martin"; }  # 1. baseline username
    // kDefaults              # 2. kind + OS derived desktop
    // isoDefaults            # 3. iso implicit defaults (explicit entry values override these)
    // entry                  # 4. explicit entry values always win
    // { name = name; };
```

`generateConfigs` filtering replaces the old `type`-string approach with predicates derived directly from registry fields:

```nix
isLinux         = e: lib.hasSuffix "-linux"  e.platform;
isDarwin        = e: lib.hasSuffix "-darwin" e.platform;
isISO           = e: e.iso or false;
isHomeOnlyEntry = e:
  let tags = e.tags or []; in
  builtins.elem "wsl" tags || builtins.elem "lima" tags || builtins.elem "steamdeck" tags;

nixosConfigurations  = entries where: isLinux && !isISO && !isHomeOnlyEntry
darwinConfigurations = entries where: isDarwin
isoConfigurations    = entries where: isISO
homeConfigurations   = all entries
```

WSL, Lima, and Steam Deck hosts are excluded from `nixosConfigurations` - WSL and Lima run foreign Linux distros (typically Ubuntu), while the Steam Deck runs SteamOS. All three only get Home Manager configurations. The `"wsl"`, `"lima"`, and `"steamdeck"` tags gate implementation-specific module content within Home Manager. A future path to system-level management (e.g. Numtide's `system-manager`) could change this, but is out of scope.

The revised `systems` registry for the full current host set:

```nix
systems = {

  # Linux workstations
  # desktop defaults to "hyprland" (kind = "computer", linux platform)
  # username defaults to "martin"

  vader = {
    kind        = "computer";
    platform    = "x86_64-linux";
    formFactor  = "desktop";
    gpu.vendors = [ "amd" "nvidia" ];
    tags        = [ "streamstation" "high-dpi" ];
  };
  phasma = {
    kind        = "computer";
    platform    = "x86_64-linux";
    formFactor  = "desktop";
    gpu.vendors = [ "amd" "nvidia" ];
    tags        = [ "streamstation" "high-dpi" ];
  };
  bane = {
    kind        = "computer";
    platform    = "x86_64-linux";
    formFactor  = "desktop";
    gpu.vendors = [ "amd" ];
  };
  tanis = {
    kind       = "computer";
    platform   = "x86_64-linux";
    formFactor = "laptop";
    tags       = [ "thinkpad" ];
  };
  shaa = {
    kind       = "computer";
    platform   = "x86_64-linux";
    formFactor = "laptop";
    tags       = [ "thinkpad" ];
  };
  atrius = {
    kind       = "computer";
    platform   = "x86_64-linux";
    formFactor = "laptop";
    tags       = [ "thinkpad" ];
  };
  sidious = {
    kind        = "computer";
    platform    = "x86_64-linux";
    formFactor  = "laptop";
    gpu.vendors = [ "intel" "nvidia" ];
  };
  felkor = {
    kind        = "computer";
    platform    = "x86_64-linux";
    formFactor  = "laptop";
    gpu.vendors = [ "amd" ];
  };

  # Steam Deck - non-standard username and desktop, so both explicit
  steamdeck = {
    kind       = "computer";
    platform   = "x86_64-linux";
    formFactor = "handheld";
    username   = "deck";
    desktop    = "gamescope";
    tags       = [ "steamdeck" ];
  };

  # Servers - desktop = null from kind = "server"
  malak = { kind = "server"; platform = "x86_64-linux"; gpu.vendors = [ "intel" ]; };
  maul  = { kind = "server"; platform = "x86_64-linux"; gpu.vendors = [ "nvidia" ]; };
  revan = { kind = "server"; platform = "x86_64-linux"; gpu.vendors = [ "intel" "nvidia" ]; };

  # Linux VMs
  crawler = { kind = "vm"; platform = "x86_64-linux"; };
  dagger  = { kind = "vm"; platform = "x86_64-linux"; desktop = "hyprland"; };

  # Lima VMs (Home Manager only; tag drives module selection)
  blackace = { kind = "vm"; platform = "x86_64-linux"; tags = [ "lima" ]; };
  defender = { kind = "vm"; platform = "x86_64-linux"; tags = [ "lima" ]; };
  fighter  = { kind = "vm"; platform = "x86_64-linux"; tags = [ "lima" ]; };

  # WSL (tag drives module selection)
  palpatine = { kind = "vm"; platform = "x86_64-linux"; tags = [ "wsl" ]; };

  # Darwin - platform drives isDarwin = true; desktop defaults to "aqua"
  momin = {
    kind       = "computer";
    platform   = "aarch64-darwin";
    formFactor = "laptop";
  };

  # ISO - iso = true applies isoDefaults: desktop = null, username = "nixos"
  iso-console = {
    kind     = "computer";
    platform = "x86_64-linux";
    iso      = true;
  };

};
```

Each entry point populates `noughty.*` values from the resolved registry entry via its `specialArgs`/`extraSpecialArgs`:

```nix
# nixos/default.nix
{ hostname, username, desktop, ... }:
{
  imports = [ ../lib/noughty ];
  noughty.host.name        = hostname;
  noughty.host.kind        = hostKind;
  noughty.host.platform    = platform;
  noughty.host.desktop     = desktop;
  noughty.host.formFactor  = hostFormFactor;
  noughty.host.gpu.vendors = hostGpuVendors;
  noughty.host.tags        = hostTags;
  noughty.host.is.iso      = hostIsIso;
  noughty.user.name        = username;
}
```

The same pattern is repeated in `darwin/default.nix` and `home-manager/default.nix` using their respective bootstrap mechanisms.


## What Stays as specialArgs

📌 **Not everything can move.** Some values are needed before module evaluation completes, or are not configuration at all.

### Must remain as specialArgs

| Value | Reason |
|-------|--------|
| `inputs` | Flake inputs are not configuration. Modules need them to reference other flakes. Cannot be an option. |
| `outputs` | Same as `inputs`. |
| `hostname` | Needed in `imports` expressions (e.g., `./${hostname}` in `nixos/default.nix`) which evaluate before `config` is available. Copied to `noughty.host.name` by the entry point. |
| `username` | Same import-time need (e.g., `lib.optional (builtins.pathExists ./${username}) ./${username}`). Copied to `noughty.user.name` by the entry point. |
| `desktop` | ~~Used in conditional imports.~~ **Removed from specialArgs.** Desktop mixins are imported unconditionally; `config.noughty.host.desktop` replaces the specialArg in all module bodies. The entry point no longer needs `desktop` at evaluation time. |
| `stateVersion` | Simple scalar, directly consumed by `system.stateVersion` and `home.stateVersion`. No benefit from being an option. |
| `catppuccinPalette` | Complex attribute set with functions. Out of scope for this project. Stays as specialArg permanently. |

### Move to noughty options

| Value | Current specialArg | New option |
|-------|-------------------|------------|
| `isWorkstation` | All three | `noughty.host.is.workstation` |
| `isServer` | All three | `noughty.host.is.server` |
| `isLaptop` | All three | `noughty.host.is.laptop` |
| `isISO` | All three | `noughty.host.is.iso` |
| `isInstall` | All three | Dropped. Use `!config.noughty.host.is.iso` directly. |
| `isLima` | NixOS + Home Manager | tag `"lima"` on `kind = "vm"` hosts |
| `tailNet` | NixOS only | `noughty.network.tailNet` |

### Reduced specialArgs after migration

**NixOS (`mkNixos`):**
```nix
specialArgs = {
  inherit inputs outputs hostname username stateVersion catppuccinPalette;
  inherit (resolvedEntry) platform hostKind hostFormFactor hostGpuVendors hostTags hostIsIso;
};
```

**Home Manager (`mkHome`):**
```nix
extraSpecialArgs = {
  inherit inputs outputs hostname username stateVersion catppuccinPalette;
  inherit (resolvedEntry) platform hostKind hostFormFactor hostGpuVendors hostTags hostIsIso;
};
```

**Darwin (`mkDarwin`):**
```nix
specialArgs = {
  inherit inputs outputs hostname username stateVersion catppuccinPalette;
  inherit (resolvedEntry) platform hostKind hostFormFactor hostGpuVendors hostTags hostIsIso;
};
```

All three are now consistent. `desktop`, boolean flags, `tailNet`, `type`, and all computed derivatives are removed from the `specialArgs` set proper. `hostname` and `username` remain solely for import-time path construction at the entry points; no module body below the entry points uses them directly.


## Migration Path

The migration is designed to be incremental. At no point does anything break. Each phase is independently verifiable with `just eval` and `just build`.

### Phase 0: Create the module (no consumers)

1. Create `lib/noughty/default.nix` with all option declarations, derived defaults, and `_module.args.noughtyLib` setter.
2. Create `lib/noughty-helpers.nix` with pure helper functions.
3. Import the noughty module (`../lib/noughty`) in `nixos/default.nix`, `darwin/default.nix`, and `home-manager/default.nix`.
4. In `lib/helpers.nix`, pass the existing registry values to the noughty module's options alongside the existing specialArgs. Both old and new paths coexist.
5. Run `just eval` and `just build` to verify no breakage.

**Result:** `config.noughty.*` and `noughtyLib` are available in every module, but nothing uses them yet. All existing specialArgs still work.

### Phase 1: Migrate the registry

1. Replace `type` with `kind`, `platform`, `formFactor`, `tags`, and `iso` in all registry entries in `flake.nix`.
2. Replace `typeDefaults` with the `resolveEntry` function in `lib/helpers.nix`.
3. Update `generateConfigs` to use predicate functions instead of `type` string matching.
4. Thread `kind`, `platform`, `formFactor`, `tags`, and `iso` through to the entry points and set corresponding `noughty.*` values.
5. Document canonical tag vocabulary in a comment block in `flake.nix`.
6. Run `just eval` and `just build`.

**Result:** Registry is clean. `config.noughty.*` is fully populated. No consumer code has changed yet.

### Phase 2: Remove `desktop` from specialArgs

This proves the unconditional-import pattern and delivers the first specialArg removal. It affects only the ~6 desktop hub modules that have `imports` - these require the long-form `{ imports = [...]; config = lib.mkIf ... { ... }; }` pattern (see [Pattern 9](#pattern-9-long-form-module-with-sub-imports-6-hub-modules)). The ~200 leaf modules migrated in Phase 3 use the flat patterns from Patterns 1-5.

1. In `nixos/default.nix` and `home-manager/default.nix`, make `./_mixins/desktop` an unconditional import.
2. Convert `nixos/_mixins/desktop/default.nix` to the long-form module pattern: `imports` stay unconditional at the top level; wrap the config body in `config = lib.mkIf config.noughty.host.is.workstation { ... }`. The long-form is required because this module has `imports` - see [Pattern 9](#pattern-9-long-form-module-with-sub-imports-6-hub-modules) for why.
3. Replace the `pathExists`-gated inner import with unconditional imports of all desktop subdirectories (`./hyprland`, `./wayfire`, `./aqua`).
4. Convert each desktop subdirectory's `default.nix` to the long-form pattern: `imports` unconditional, `config = lib.mkIf (config.noughty.host.desktop == "x") { ... }`. Modules without `imports` (e.g. `greetd.nix`) use the flat pattern directly.
5. In `home-manager/_mixins/desktop/default.nix`, convert to the long-form pattern: `imports` unconditional at the top level, `config = lib.mkIf config.noughty.host.is.workstation ( let ... in { ... } )`. Place the `let` block inside the `config` gate so bindings that read `desktop` (which is `null` on non-workstation systems) are not forced. Replace `desktop` function argument with `config.noughty.host.desktop`. Apply the same unconditional compositor imports.
6. Remove `desktop` from `specialArgs`/`extraSpecialArgs` in `lib/helpers.nix`.
7. Run `just eval` and `just build`.

⚠️ **Verify with a non-workstation build.** After step 7, explicitly build a server (e.g. `just build-host malak`) and a VM. `let` bindings inside the `config` gate are still evaluated to thunks - Nix's laziness means they won't be *forced* when the condition is false, but any binding that unconditionally calls a function on `desktop` (which is `null` on non-workstation systems) will produce a type error if forced. A successful `just build` on the current host is not sufficient if that host is a workstation - the `lib.mkIf` path is never false during that build.

**Result:** `desktop` is gone from specialArgs. The unconditional-import + internal gate pattern is established and proven. Only ~6 hub modules use the long-form pattern; all other modules are unchanged.

### Phase 3: Migrate module bodies off `hostname` and `username`

`hostname` and `username` remain in specialArgs for their irreducible import-time uses, but are removed from every module body below the entry points.

1. Replace every `hostname ==` and `hostname !=` comparison with `config.noughty.host.name ==` or `noughtyLib.isHost`.
2. Replace every `lib.elem username` / `installFor` pattern with `noughtyLib.isUser`.
3. Replace every `isWorkstation`, `isServer`, etc. reference with `config.noughty.host.is.*`.
4. Replace scattered `hostname == "phasma" || hostname == "vader"` patterns with `noughtyLib.hostHasTag` or `noughtyLib.isHost`.
5. Remove `hostname` and `username` from the function argument lists of all modules that no longer need them directly.

**Order of conversion** (by risk, lowest first):

1. `installFor` user-gated modules (~30 files) - mechanical replacement.
2. `installOn` host-gated modules (~15 files) - mechanical replacement.
3. Boolean flag consumers (`isWorkstation`, `isServer`, etc.) not in `imports` (~150 occurrences) - straightforward.
4. Scattered `hostname == "x"` comparisons that map cleanly to tags (~30 occurrences).
5. Host-specific values (display resolution, hwmon paths) - leave as-is or move to per-host noughty options in Phase 5.

Each conversion is a single-file change that can be reviewed independently.

**Result:** `hostname` and `username` exist in specialArgs but are unused in any module body below the entry points. All module bodies read `config.noughty.*` or call `noughtyLib.*`.

### Phase 4: Remove redundant specialArgs

Once no module body references the old specialArg names:

1. Remove `isWorkstation`, `isServer`, `isLaptop`, `isISO`, `isLima`, `tailNet` from all three `specialArgs` blocks.
2. Remove the duplicated boolean computation from `mkHome`, `mkNixos`, `mkDarwin`.
3. Final specialArgs: `inputs`, `outputs`, `hostname`, `username`, `stateVersion`, `catppuccinPalette`, plus resolved registry values needed to populate `noughty.*`.

**Result:** specialArgs are at their minimum. The migration is complete for all practical purposes.

### Phase 5: Consolidate per-host display configuration

Display output data (output names, resolutions, refresh rates, positions, workspace assignments) is duplicated across 9 files in at least 3 different formats. This phase centralises it.

1. Add `noughty.host.displays` list-of-submodules option and derived `noughty.host.display.*` values to `lib/noughty/default.nix`.
2. For each workstation host, add `noughty.host.displays = [ ... ];` to its host module (`nixos/{hostname}/default.nix` or equivalent).
3. Migrate `compositor/hyprland/monitors.nix` to generate Hyprland monitor strings from `config.noughty.host.displays`.
4. Migrate `compositor/components/hyprlock/`, `hyprpaper/`, `waybar/`, `fuzzel/` to read `config.noughty.host.display.*` instead of hostname chains.
5. Migrate `nixos/_mixins/desktop/greeters/greetd.nix` to derive wallpaper resolution and kanshi profiles from `config.noughty.host.displays`.
6. Optionally, generate kernel `video=` params from `displays` in each host module.
7. Run `just eval` and `just build`.

**Order of conversion** (by impact, highest first):

1. `hyprlock` and `waybar` - use only `display.primaryOutput` and `display.primaryWidth`. Simplest consumers.
2. `hyprpaper` - maps outputs to resolution-matched wallpapers. Straightforward map over `displays`.
3. `greetd.nix` - wallpaper resolution and kanshi profiles. Kanshi config is fully derivable from `displays`.
4. `monitors.nix` - the largest file. Generates Hyprland monitor strings and workspace binds from `displays`.
5. `fuzzel` and layout params - derive from primary width. Lowest priority.

**Result:** Display data declared once per host. Nine files with hostname chains reduced to consumers of structured data. Adding a new workstation means setting `noughty.host.displays` in one file.


## Resolving the `imports` Problem

Nix evaluates `imports` before `config` is available, which appears to block the migration of any specialArg used in an `imports` expression. In practice, only two of the three affected patterns are a genuine constraint. The third is resolved by the mixin pattern itself.

### The three affected patterns

#### Pattern A: `lib.optional isWorkstation ./_mixins/desktop`

This conditional import exists in both `nixos/default.nix` and `home-manager/default.nix`. It is **fully resolvable** using the unconditional import + internal gate approach:

```nix
# nixos/default.nix - import unconditionally
imports = [ ... ./_mixins/desktop ];

# nixos/_mixins/desktop/default.nix - long-form module: imports stay unconditional, config is gated
{ config, lib, pkgs, ... }:
{
  imports = [
    ./apps
    ./backgrounds
    ./hyprland
    ./wayfire
    ./aqua
  ];
  config = lib.mkIf config.noughty.host.is.workstation {
    boot     = { ... };
    programs = { ... };
    services = { ... };
  };
}
```

⚠️ **Why the long-form pattern?** `imports` cannot appear inside `lib.mkIf` - the module system resolves `imports` before `config` is available, so conditional imports based on `config` values cause infinite recursion. The long-form `{ imports = [...]; config = lib.mkIf ... { ... }; }` pattern separates the two concerns: sub-modules are always imported (and gate themselves internally), while config is conditionally applied. See [Pattern 9](#pattern-9-long-form-module-with-sub-imports-6-hub-modules) for the full explanation and decision guide.

Each desktop subdirectory gates on the specific compositor value:

```nix
# nixos/_mixins/desktop/hyprland/default.nix - also long-form (has imports)
{ config, lib, ... }:
{
  imports = [ ../greeters/greetd.nix ];
  config = lib.mkIf (config.noughty.host.desktop == "hyprland") { ... };
}
```

Modules without `imports` use the flat pattern directly:

```nix
# nixos/_mixins/desktop/greeters/greetd.nix - flat pattern (no imports)
{ config, lib, ... }:
lib.mkIf config.noughty.host.is.workstation { ... }
```

This is safe: a module whose entire `config` is `lib.mkIf false { ... }` is fully evaluated (option declarations, function arguments) but contributes nothing to the system configuration. This is the standard NixOS mixin pattern.

The `builtins.pathExists` guard previously used inside the desktop mixin (`lib.optional (pathExists ./${desktop}) ./${desktop}`) was defensive - all desktop subdirectories exist in the repo. With typed `noughty.host.desktop`, typo protection moves to option validation. The `pathExists` check is dropped.

In `home-manager/_mixins/desktop/default.nix`, the large `let` block computing theme values from `desktop` must move inside the `config` gate to avoid evaluation failures on non-workstation systems (where `desktop` is `null`). The long-form pattern places `imports` outside and the `let` block inside `config`:

```nix
{ catppuccinPalette, config, lib, pkgs, ... }:
{
  imports = [
    ./apps
    ./compositor/hyprland
    ./compositor/wayfire
    ./compositor/aqua
  ];
  config = lib.mkIf config.noughty.host.is.workstation (
    let
      desktop = config.noughty.host.desktop;  # read from noughty, not specialArg
      # all existing theme computations unchanged
    in
    {
      # each compositor/x/default.nix gates on config.noughty.host.desktop == "x"
    }
  );
}
```

`desktop` is removed from `specialArgs`/`extraSpecialArgs` entirely. No module below the entry point lists it as a function argument.

#### Pattern B: `imports = [ ./${hostname} ]` and `imports = lib.optional (pathExists ./${username}) ./${username}`

These **cannot use `config`**. The module system resolves `imports` before evaluation begins - there is no mechanism to compute an import path from an evaluated option value. This is an irreducible constraint of the Nix module system, not a gap in the design.

The alternative of enumerating all host directories unconditionally is technically possible but architecturally harmful: every host's hardware configuration would be imported into every build, the option tree would carry config from 20+ hosts simultaneously, and evaluation cost would scale linearly with the number of hosts.

📌 **`hostname` and `username` stay in `specialArgs`/`extraSpecialArgs` - but solely for these import-time uses.** They are copied into `noughty.host.name` and `noughty.user.name` immediately at the entry point. No module below the entry point lists them as function arguments. All module bodies read `config.noughty.host.name` and `config.noughty.user.name` instead.

#### Pattern C: `modules = [ ../nixos ] ++ lib.optionals isISO [ cd-dvd ]`

This is in `mkNixos` in `lib/helpers.nix`, passed as the `modules` argument to `nixpkgs.lib.nixosSystem`. It is outside the module system entirely - `config` does not exist at this point. This must remain a pre-evaluation conditional permanently; it is the correct mechanism for this use case.

With the new registry structure, `isISO` becomes `entry.iso or false`:

```nix
modules = [ ../nixos ] ++ lib.optionals (entry.iso or false) [ cd-dvd ];
```

No change to the approach - only to the source of the boolean.

### End state for specialArgs

After fully applying this strategy, the specialArgs set across all three systems becomes:

```nix
# Consistent across mkNixos, mkDarwin, and mkHome (extraSpecialArgs):
specialArgs = {
  inherit inputs outputs hostname username stateVersion catppuccinPalette;
  inherit (resolvedEntry) platform hostKind hostFormFactor hostGpuVendors hostTags hostIsIso;
};
```

Twelve values, down from 15+, consistent across all three systems. The resolved registry values (`platform`, `hostKind`, `hostFormFactor`, `hostGpuVendors`, `hostTags`, `hostIsIso`) remain permanently - entry points need them to populate `noughty.*` options. Removed entirely: `desktop`, `isWorkstation`, `isServer`, `isLaptop`, `isISO`, `isLima`, `tailNet`, and all computed booleans.

### Module system overhead

Declaring options adds a small amount of evaluation overhead compared to raw specialArgs. For the scale of this configuration (20+ hosts, ~100 modules), this is negligible. The Nix module system evaluates lazily; unused options cost nothing.

### Learning curve

Contributors need to know that system attributes live in `config.noughty.*` and helpers in `noughtyLib` rather than function arguments. This is simpler than the current approach, where you must know which specialArgs exist, which of the three `mk*` functions defines them, and whether the one you need is available in your module system.

### Tag discipline

Host and user tags are freeform `listOf str`. Nothing prevents typos like `"streamstaion"`. Two mitigations:

1. Document canonical tag vocabulary in a comment block in the registry section of `flake.nix`. This is the single designated source of truth for tag names.
2. Optionally, define an `enum` of known tags and validate in the module. This adds maintenance cost but catches typos at evaluation time.

→ **Recommendation:** Start with documented conventions. Add validation only if typos become a real problem in practice.

The `is.laptop` flag is no longer vulnerable to this concern - it derives from `formFactor == "laptop"`, a typed enum, not from tag discipline.

### Per-host display values addressed by Phase 5

The long `if hostname == "vader" then ... else if hostname == "phasma" then ...` chains in waybar, hyprlock, hyprpaper, greetd, and fuzzel are not served by tags or boolean flags. They need structured per-host data. `noughty.host.displays` (see [Display output configuration](#noughtyhostdisplays---display-output-configuration)) provides this, with derived values like `display.primaryOutput` and `display.primaryWidth` that replace the most common hostname lookups. Phase 5 handles the migration.

### `catppuccinPalette` remains out of scope

`catppuccinPalette` is a complex attribute set with functions. It does not share the fragility problems of the boolean flags (it is self-contained and consistently available). It stays as a `specialArgs` value and is explicitly out of scope for this project.


## Summary of Decisions

| Decision | Resolution |
|----------|-----------|
| Module namespace | `noughty` |
| Where the module lives | `lib/noughty/default.nix` (single shared file, no per-system wrappers) |
| Helper functions location | `lib/noughty-helpers.nix` (pure functions, called from `_module.args` setter) |
| Helper delivery mechanism | `_module.args.noughtyLib` - available as a module argument like `lib` or `pkgs` |
| Infinite recursion risk | Mitigated: `_module.args` functions close over `config.noughty.*` lazily |
| Cross-system sharing | One shared file; entry points populate values from `specialArgs`/`extraSpecialArgs` |
| What stays as specialArgs | `inputs`, `outputs`, `hostname`, `username`, `stateVersion`, `catppuccinPalette` |
| `desktop` in specialArgs | **Removed.** Desktop mixins imported unconditionally; each subdirectory gates on `config.noughty.host.desktop == "x"` |
| `hostname` / `username` in specialArgs | Retained solely for import-time path construction (`./${hostname}`, `./${username}`). Never used in module bodies below entry points. |
| Registry `type` field | **Removed.** Replaced by `kind`, `platform`, `formFactor`, `tags`, and `iso = true` |
| `platform` in registry | Required field, no default. Missing `platform` is an immediate evaluation error. |
| `typeDefaults` | Replaced by `resolveEntry` in `lib/helpers.nix` - four-layer merge, no lookup tables |
| ISO handling | `iso = true` boolean field; implicitly sets `desktop = null` and `username = "nixos"` (overridable) |
| Host classification | `noughty.host.kind`: enum `["computer" "server" "vm" "container"]` |
| Lima/WSL classification | `kind = "vm"` with tags `"lima"` / `"wsl"` - no separate `kind` values |
| Physical form | `noughty.host.formFactor`: `nullOr (enum ["laptop" "desktop" "handheld" "tablet" "phone"])` |
| OS detection | `noughty.host.os`: derived from `platform`, read-only, values `"linux"` / `"darwin"` |
| `isLaptop` fix | Derived from `formFactor == "laptop"` - no negative hostname list, no tag discipline required |
| Tags | Two lists: `noughty.host.tags` (hardware/role) and `noughty.user.tags` (persona/role) |
| Tag type | `listOf str` (freeform); canonical vocabulary documented in `flake.nix` |
| Tag helpers | `noughtyLib.hostHasTag`, `noughtyLib.userHasTag`, and variant forms |
| Removed `is.*` flags | `is.lima`, `is.wsl`, `is.gaming`, `is.install` removed; Lima/WSL use tags `"lima"`/`"wsl"`; Steam Deck uses tag `"steamdeck"`; `is.install` dropped as redundant negation of `is.iso` |
| Added `is.*` flags | `is.linux` and `is.darwin` added (derived from `os`) |
| ISO exclusion guard | Explicit `!config.noughty.host.is.iso` - no hidden conditions baked into helpers |
| `catppuccinPalette` | Stays as specialArg permanently; explicitly out of scope |
| GPU classification | `noughty.host.gpu.vendors`: `listOf (enum ["nvidia" "amd" "intel"])` with derived booleans (`hasNvidia`, `hasAmd`, `hasIntel`, `hasAny`, `hasCuda`) |
| GPU scope | Vendor presence only; per-host PCI bus IDs, PRIME, kernel modules stay in host directories |
| Display configuration | `noughty.host.displays`: list of submodules (output, width, height, refresh, scale, position, primary, workspaces) with derived `display.*` shortcuts |
| Display data location | Set in host modules (not registry); too verbose and hardware-specific for `flake.nix` |
| Migration approach | Incremental, file-by-file; old and new paths coexist throughout |


## Appendix A: noughtyLib as specialArg - Design Analysis

**Status:** Research complete
**Date:** 2026-02-19
**Conclusion:** Do not adopt. The imports problem is smaller than it appears and has cleaner solutions.

### 1. The Proposal

Construct `noughtyLib` (or a subset of it) at `specialArgs`/`extraSpecialArgs` construction time in `lib/helpers.nix`, rather than (or in addition to) via `_module.args` inside the noughty module. This would make `noughtyLib.hostname`, `noughtyLib.isHost`, `noughtyLib.hostHasTag`, etc. available in `imports` blocks, where `config` does not yet exist.

The motivation is to solve the "imports problem" - the three files that use `hostname` in import paths:

| File | Usage |
|------|-------|
| `nixos/default.nix` | `./${hostname}` in imports |
| `darwin/default.nix` | `./${hostname}` in imports |
| `nixos/_mixins/network/default.nix` | `lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix` in imports |


### 2. What It Would Solve

**Import-time access to identity values.** A specialArg-based `noughtyLib` would make hostname, tags, and tag-checking helpers available before `config` is fixed. In principle, modules could write:

```nix
{ noughtyLib, lib, ... }:
{
  imports = lib.optional (noughtyLib.hostHasTag "custom-network") ./custom-network.nix;
}
```

**Consistent API surface.** Modules would use `noughtyLib.*` for everything - identity checks, tag queries, and (if fully adopted) hostname and username access. No need to mix `noughtyLib` and `config.noughty.*` for identity-related values.

**Potential to eliminate the `hostname` specialArg.** If `noughtyLib.hostname` were available as a specialArg, the bare `hostname` specialArg could be replaced entirely - `noughtyLib` becomes the single namespace for all identity access.


### 3. Trade-offs

#### 3.1 specialArgs are static; options are overridable

`specialArgs` values are computed once in `lib/helpers.nix` and are immutable for the entire module evaluation. They cannot reflect `lib.mkDefault`, `lib.mkForce`, or module-system merging.

Consider a hypothetical scenario where a host module does:

```nix
# nixos/vader/default.nix
noughty.host.tags = lib.mkForce [ "maintenance-mode" ];
```

With the current `_module.args` approach, `noughtyLib.hostHasTag "streamstation"` would correctly return `false` after this override because it closes over `config.noughty.host.tags` lazily. With a specialArg-based `noughtyLib`, it would still return `true` because it was constructed from the registry value before module evaluation began.

📌 **This is the fundamental tension.** The `_module.args` approach was chosen specifically because it participates in the module system's laziness. Moving to `specialArgs` sacrifices this property.

⚠️ **Realistic risk assessment:** In this repository, `noughty.host.tags` and `noughty.host.name` are set once at the entry point from registry values and are never overridden by downstream modules. No host module currently uses `lib.mkForce` on identity values. The override scenario above is hypothetical. However, the *ability* to override is a design principle of the noughty module - the README explicitly states "Each uses `lib.mkDefault` so host-specific modules can override with `lib.mkForce`." Making identity values static would quietly remove this guarantee for a subset of the option space.

#### 3.2 Two sources of truth

If `noughtyLib` is a specialArg carrying identity values, and `config.noughty.host.*` also carries the same values as options, there are two paths to the same data:

| Access path | Source | Overridable? | Available in imports? |
|---|---|---|---|
| `noughtyLib.hostname` | specialArg (static) | No | Yes |
| `config.noughty.host.name` | Option (merged) | Yes | No |

This creates a class of subtle bugs: a module author reads `noughtyLib.hostname` (thinking it is authoritative) while another module has overridden `config.noughty.host.name` via `lib.mkForce`. The two values silently disagree. The current design has one source of truth - `config.noughty.*` - and `noughtyLib` is a convenience lens over it.

#### 3.3 The hybrid approach (specialArg for identity, _module.args for derived values)

A middle ground: construct a *minimal* specialArg `noughtyLib` carrying only static identity (hostname, tags, username) and keep the `_module.args` version for config-derived helpers (the `is.*` flags, display values, etc.).

This is technically feasible but introduces a confusing dual-delivery model:

- **specialArg `noughtyLib`**: contains `hostname`, `isHost`, `hostHasTag`, `isUser`, `userHasTag`
- **_module.args `noughtyLib`**: contains the same functions, but closing over `config` values

These cannot both be named `noughtyLib` without one shadowing the other. The `_module.args` version would win (it is evaluated later), meaning `noughtyLib.isHost` in a module body uses the config-derived version, but `noughtyLib.isHost` in an `imports` block would fail because `_module.args` is not available there - it would fall back to the specialArg version silently only if the specialArg were named differently (e.g. `noughtyIdentity`).

→ This adds complexity without proportional benefit.

#### 3.4 A specialArg cannot read from config

It is worth stating explicitly: a specialArg-based `noughtyLib` **cannot** close over `config.noughty.*` values. `specialArgs` are set before module evaluation begins. There is no mechanism for a specialArg to lazily reference evaluated option values. This is not a limitation that can be worked around - it is inherent to the module system's evaluation order.


### 4. Alternative Solutions

The imports problem affects exactly three files. Each has a targeted solution that does not require changing the noughtyLib delivery mechanism.

#### 4.1 Entry-point host imports (nixos/default.nix, darwin/default.nix)

These use `./${hostname}` to import host-specific hardware configuration (disk layout, kernel modules, nixos-hardware imports). This is an **irreducible** use of `hostname` at import time - the host directory contains hardware-specific modules that cannot be imported unconditionally without importing every host's configuration into every build.

📌 **Already solved.** The current design retains `hostname` in `specialArgs` specifically for this purpose. The README documents this as Pattern B in "Resolving the `imports` Problem". Moving `hostname` into `noughtyLib` would not change the mechanism - it would still be a pre-evaluation value passed from outside the module system.

→ **No change needed.** `hostname` stays as a specialArg. A specialArg-based `noughtyLib.hostname` would be a rename, not a solution.

#### 4.2 Network per-host imports (nixos/_mixins/network/default.nix)

This uses `lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix` to conditionally import per-host network config. Currently, four per-host files exist: `vader.nix`, `phasma.nix`, `revan.nix`, `malak.nix`.

This **can be solved without changing noughtyLib delivery**, using the same unconditional-import + internal-gate pattern established in Phase 2:

```nix
# nixos/_mixins/network/default.nix
{
  imports = [
    ./nullmailer
    ./ssh
    ./tailscale
    ./vader.nix      # unconditional
    ./phasma.nix     # unconditional
    ./revan.nix      # unconditional
    ./malak.nix      # unconditional
  ];
  # ... rest of config
}
```

Each per-host file gates itself internally:

```nix
# nixos/_mixins/network/vader.nix
{ config, lib, noughtyLib, ... }:
lib.mkIf (noughtyLib.isHost [ "vader" ]) {
  networking.networkmanager = lib.mkIf config.networking.networkmanager.enable {
    connectionConfig = {
      "ethernet.mtu" = 1462;
      "wifi.mtu" = 1462;
    };
    wifi.powersave = true;
  };
}
```

This eliminates the `pathExists` + `hostname` import pattern entirely. New per-host network files are added to the imports list and gate themselves internally. The cost is trivial: four modules whose `config` is `lib.mkIf false { ... }` contribute nothing to non-matching hosts.

→ **Recommended approach.** Solves the third imports-problem file cleanly within the existing architecture.

#### 4.3 Moving host imports into lib/helpers.nix

An alternative for the entry-point imports: construct the host-specific module path in `mkNixos`/`mkDarwin` and pass it via the `modules` list:

```nix
mkNixos = { hostname, ... }:
  inputs.nixpkgs.lib.nixosSystem {
    modules = [
      ../nixos
      ../nixos/${hostname}   # host-specific import moved here
      { noughty.host.desktop = desktop; }
    ];
  };
```

This removes `./${hostname}` from `nixos/default.nix` entirely, but shifts import logic out of the module tree into the helper function. It works and would allow removing `hostname` from `specialArgs` for the entry-point import use, but `hostname` is still needed in module bodies for sops secret paths (`../secrets/host-${hostname}.yaml`) and other string interpolation references until those are migrated to `config.noughty.host.name`.

→ **Viable but marginal.** Does not eliminate `hostname` from specialArgs because other non-import uses remain during migration. Could be revisited as a final cleanup step.


### 5. Recommendation

**Do not adopt noughtyLib-as-specialArg.** The costs outweigh the benefits for this repository.

| Factor | Assessment |
|--------|-----------|
| Problem scope | 3 files use `hostname` in imports. 2 are irreducible. 1 is solvable with unconditional imports. |
| Benefit | Eliminates `hostname` from specialArgs only if *all* import-time uses are removed - which they cannot be. |
| Cost: dual truth | Creates two disagreeable sources for identity values (static specialArg vs overridable option). |
| Cost: override loss | Silently removes `lib.mkForce` overridability for identity values. |
| Cost: complexity | Hybrid model requires two delivery mechanisms or two differently-named APIs. |
| Module system philosophy | `specialArgs` are for bootstrapping (`inputs`, `outputs`). Configuration belongs in options. `_module.args` is the correct mechanism for config-derived helpers. |

The current design is sound:
- `hostname` stays as a specialArg for the two irreducible import-time uses.
- `noughtyLib` stays as `_module.args` to preserve lazy config closure and overridability.
- The network per-host import (the only *solvable* imports-problem file) should be migrated to unconditional imports with internal `noughtyLib.isHost` gates.

After that migration, the "imports problem" is fully resolved: two entry-point uses of `hostname` remain as an irreducible, well-documented architectural constraint, and the third is eliminated.


### 6. If Adopted (Hypothetical)

For completeness, here is what would change if the specialArg approach were adopted despite the recommendation above.

**lib/helpers.nix changes:**
- Import `noughty-helpers.nix` at the top level.
- In each `mk*` function, construct a `noughtyLib` attrset by calling the helpers with the resolved registry values (`hostname`, `hostTags`, `username`, `userTags`).
- Add `noughtyLib` to `specialArgs`/`extraSpecialArgs` in all three functions.
- Optionally add `hostname` and `username` as direct attributes on `noughtyLib` (e.g. `noughtyLib.hostname`).

**lib/noughty/default.nix changes:**
- Remove the `_module.args.noughtyLib` setter, **or** keep it and accept that the `_module.args` version shadows the specialArg version in module bodies (this is actually the Nix module system's defined behaviour - `_module.args` wins over `specialArgs` for identically-named values).
- If both are kept: specialArg `noughtyLib` would only be visible in `imports` blocks (where `_module.args` is not available). In module bodies, the `_module.args` version takes precedence. This is confusing but technically correct.

**Consumer module changes:**
- No changes required. `noughtyLib` in module bodies would continue to work identically (the `_module.args` version shadows the specialArg).
- Modules that want to use `noughtyLib` in `imports` blocks would gain access to the static specialArg version - but only for identity checks, not for config-derived values like `is.workstation`.

**Risk:**
- The `noughtyLib` visible in `imports` and the `noughtyLib` visible in `config` would be *different objects* with the same name, constructed from different sources (registry vs config). An `isHost` call that returns `true` in imports could hypothetically return `false` in the same module's config body if someone overrode `noughty.host.name` via `lib.mkForce`. This is a new class of confusion that does not exist today.
