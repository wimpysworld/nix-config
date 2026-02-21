# Noughty

Centralised system attributes module for a NixOS, nix-darwin, and Home Manager flake. Replaces ad-hoc `specialArgs` threading with typed, overridable NixOS-style options under the `noughty` namespace.

## Contents

- [Why Noughty exists](#why-noughty-exists)
- [Architecture](#architecture)
- [Data flow](#data-flow)
- [Option reference](#option-reference)
- [Helper function reference](#helper-function-reference)
- [Usage patterns](#usage-patterns)
- [The long-form `config = lib.mkIf` pattern](#the-long-form-config--libmkif-pattern)
- [CLI tool](#cli-tool)
- [What stays as specialArgs](#what-stays-as-specialargs)
- [Adding a new host](#adding-a-new-host)
- [Extending the module](#extending-the-module)
- [Design decisions](#design-decisions)

## Why Noughty exists

The repository previously threaded 15+ computed values (`isLaptop`, `isWorkstation`, `username`, `hostname`, `tailNet`, etc.) through `specialArgs`/`extraSpecialArgs` to every module. This had concrete costs:

1. **Triplicated logic.** Boolean flags were computed identically in `mkHome`, `mkNixos`, and hardcoded differently in `mkDarwin`. Every new flag required editing three functions.
2. **Fragile negative lists.** `isLaptop` was defined as `hostname != "vader" && hostname != "phasma" && ...`. Adding a new desktop meant remembering to update the list.
3. **Inconsistent flag availability.** `tailNet` existed only in `mkNixos`. Modules could not rely on a consistent attribute set.
4. **Scattered gating patterns.** At least four distinct patterns across 90+ files for the same kind of conditional.
5. **No type safety.** Misspelling `isWorkstaion` silently received `null` rather than raising an error.
6. **No overridability.** `specialArgs` values were immutable; a host could not override central logic.

Noughty replaces all of this with a single NixOS options module. The module system provides type checking, defaults, `mkDefault`/`mkForce` overridability, and option documentation. Helper functions in `lib/` cannot.

## Architecture

### File layout

```
lib/
  noughty/
    default.nix          # Option declarations, derived defaults, _module.args.noughtyLib setter
    README.md            # This file
  noughty-helpers.nix    # Pure helper functions (no module system dependency)
  flake-builders.nix     # resolveEntry, mkNixos, mkHome, mkDarwin, mkSystemConfig

nixos/default.nix        # Imports ../lib/noughty
darwin/default.nix       # Imports ../lib/noughty
home-manager/default.nix # Imports ../lib/noughty

flake.nix                # Imports registry files, wires inputs/outputs
lib/registry-systems.toml # System registry (all host definitions)
lib/registry-users.toml   # User profiles (per-user metadata)

home-manager/_mixins/scripts/noughty/
  default.nix            # CLI tool wrapper (bakes config values at build time)
  noughty.sh             # CLI tool implementation
```

### Why TOML for the registries

The system and user registries (`registry-systems.toml`, `registry-users.toml`) use TOML rather than Nix syntax for three reasons.

First, noughty is designed to be reusable outside this flake - specifically with [Noughty Linux](https://github.com/noughtylinux/config), where users managing their system configuration should not need to know Nix to add or modify a host entry. TOML is widely familiar and editable with any text editor or standard tooling.

Second, a TOML registry is consumable by non-Nix tooling (Python, Rust, shell scripts) without a Nix evaluator, enabling inventory scripts, dashboards, or CI tooling to read host metadata directly.

Third, `builtins.fromTOML` has been a stable Nix built-in since Nix 2.3, requiring no additional dependencies. The parsed output is structurally identical to a Nix attrset, so no downstream module code changed when the registries were migrated from `.nix` files.

### Separation of concerns

- **`lib/noughty/default.nix`** declares options and derives defaults. Uses only `lib` and `config`, making it safe to import verbatim into all three module system contexts (NixOS, nix-darwin, Home Manager).
- **`lib/noughty-helpers.nix`** contains pure functions with no module system dependency. Independently testable.
- **`lib/flake-builders.nix`** bridges the registry and the module system. `resolveEntry` merges registry defaults; `mkSystemConfig` produces the attribute set that `mkNixos`/`mkHome`/`mkDarwin` consume.

## Data flow

```
lib/registry-systems.toml (system registry, read by flake.nix via builtins.fromTOML)
  -> lib/flake-builders.nix: resolveEntry merges four layers (baseline, kind defaults, iso defaults, explicit values)
    -> mkSystemConfig produces { hostname, username, desktop, hostKind, hostGpuVendors, ... }
      -> mkNixos/mkHome/mkDarwin set noughty.* options in the modules list
        -> lib/noughty/default.nix computes derived booleans as option defaults
          -> _module.args.noughtyLib provides convenience helpers
            -> modules read config.noughty.* or call noughtyLib.*
```

### resolveEntry merge order

Each registry entry is resolved by merging four layers, where later layers win:

1. Baseline username (`"martin"`)
2. Kind + OS derived desktop (e.g. `computer` on Linux defaults to `"hyprland"`)
3. ISO implicit defaults (`desktop = null`, `username = "nixos"`)
4. Explicit entry values from the registry

### noughtyLib delivery via `_module.args`

Helper functions are injected via `_module.args.noughtyLib`, not as `specialArgs`. This preserves lazy closure over `config.noughty.*` values, meaning overrides via `lib.mkForce` are correctly reflected. A `specialArgs`-based approach was analysed and rejected because:

- `specialArgs` are static and computed before module evaluation. They cannot reflect `mkDefault`/`mkForce` overrides.
- It would create two disagreeable sources of truth for identity values (static specialArg vs overridable option).
- The imports problem it aimed to solve affects only two irreducible files.

A specialArg-based approach was analysed and rejected: specialArgs are static and computed before module evaluation, cannot reflect `mkDefault`/`mkForce` overrides, would create two disagreeable sources of truth, and the imports problem it aimed to solve affects only two irreducible entry-point files.

## Option reference

### `noughty.host` - Host identity and classification

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `host.name` | `str` | `"localhost"` | Hostname of the managed system. |
| `host.kind` | `enum ["computer" "server" "vm" "container"]` | `"computer"` | Class of host system, independent of OS or use-case. |
| `host.platform` | `str` | `"x86_64-linux"` | Architecture string (e.g. `"x86_64-linux"`, `"aarch64-darwin"`). |
| `host.desktop` | `nullOr str` | `null` | Desktop environment name, or `null` for headless systems. |
| `host.formFactor` | `nullOr (enum ["laptop" "desktop" "handheld" "tablet" "phone"])` | `null` | Physical form factor. `null` for virtual or headless systems. |
| `host.tags` | `listOf str` | `[]` | Freeform tags for host classification. Canonical vocabulary in `lib/registry-systems.toml`. |
| `host.os` | `enum ["linux" "darwin"]` | *(derived from platform)* | Read-only. Derived from `platform` suffix. |

#### Notes on `host.kind`

`kind` describes what class of system this is, independent of OS, use-case, or deployment mechanism:

| Former registry `type` | `noughty.host.kind` | Notes |
|---|---|---|
| `workstation` | `computer` | Desktop or laptop physical system |
| `gaming` / `steamdeck` | `computer` | Use-case, not a system class; use tags |
| `darwin` | `computer` | OS, not a system class; `host.os` captures this |
| `server` | `server` | Unchanged |
| `vm` / `lima` / `wsl` | `vm` | Implementation details use tags (`"lima"`, `"wsl"`) |
| `iso` | *(not applicable)* | Deployment medium, not a system class; `is.iso` boolean |

### `noughty.host.is` - Derived boolean flags

All derived from other `noughty.host.*` options. Settable (not `readOnly`), so hosts can override with `lib.mkForce`.

| Option | Type | Default derivation |
|--------|------|--------------------|
| `is.workstation` | `bool` | `desktop != null` |
| `is.server` | `bool` | `kind == "server"` |
| `is.laptop` | `bool` | `formFactor == "laptop"` |
| `is.iso` | `bool` | `false` (set from registry `iso` field) |
| `is.vm` | `bool` | `kind == "vm"` |
| `is.darwin` | `bool` | `os == "darwin"` |
| `is.linux` | `bool` | `os == "linux"` |

### `noughty.host.gpu` - GPU vendor classification

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `gpu.vendors` | `listOf (enum ["nvidia" "amd" "intel" "apple"])` | `[]` | GPU vendors present in this host. |

#### `gpu.compute` - Compute GPU submodule

Anchors compute properties to a specific GPU, resolving ambiguity on dual-GPU hosts:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `gpu.compute.vendor` | `nullOr (enum ["nvidia" "amd" "intel" "apple"])` | `null` | Which GPU handles compute workloads. |
| `gpu.compute.vram` | `int` | `0` | VRAM in GB. For unified memory (Apple Silicon, AMD Strix Halo), use the portion allocatable for GPU compute. |
| `gpu.compute.unified` | `bool` | `false` | Whether the compute GPU uses unified memory shared with the CPU. |
| `gpu.compute.acceleration` | `nullOr (enum ["cuda" "rocm" "vulkan" "metal"])` | *(auto-derived)* | Defaults: nvidia -> cuda, amd -> rocm, apple -> metal, otherwise null. Override to `"vulkan"` for cross-vendor fallback. |

#### Derived GPU booleans (read-only)

| Option | Derivation |
|--------|------------|
| `gpu.hasNvidia` | `elem "nvidia" vendors` |
| `gpu.hasAmd` | `elem "amd" vendors` |
| `gpu.hasIntel` | `elem "intel" vendors` |
| `gpu.hasApple` | `elem "apple" vendors` |
| `gpu.hasAny` | `vendors != []` |
| `gpu.hasCuda` | `compute.acceleration == "cuda"` |

Note: `hasCuda` derives from `compute.acceleration`, not vendor presence. A host with NVIDIA for video encoding but no compute block (e.g. sidious with 4GB VRAM used only for NVENC) would have `hasCuda = false` if no `compute` block is set.

#### Why structured options, not tags

A bare `hostHasTag "gpu"` cannot distinguish vendors. Hosts like vader have both AMD and NVIDIA GPUs. An enum list with derived booleans provides type validation: misspelling `"nvida"` in an enum produces an immediate evaluation error; misspelling it in a tag fails silently.

### `noughty.host.displays` - Display output configuration

A list of display submodules. Set in the system registry (`lib/registry-systems.toml`) alongside other host properties. This ensures display data flows to both NixOS and standalone Home Manager contexts.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `output` | `str` | *(required)* | Output connector name (e.g. `"DP-1"`, `"eDP-1"`). |
| `width` | `int` | *(required)* | Horizontal resolution in pixels. |
| `height` | `int` | *(required)* | Vertical resolution in pixels. |
| `refresh` | `int` | `60` | Refresh rate in Hz. |
| `scale` | `float` | `1.0` | Display scale factor. |
| `position` | `submodule { x : int; y : int }` | `{ x = 0; y = 0; }` | Display position offset in pixels. |
| `primary` | `bool` | `false` | Whether this is the primary display. |
| `workspaces` | `listOf int` | `[]` | Workspace numbers assigned to this display. |

Example:

```toml
# lib/registry-systems.toml (vader entry)
[[vader.displays]]
output     = "DP-1"
width      = 2560
height     = 2880
primary    = true
workspaces = [1, 2, 7, 8, 9]
position   = { x = 0, y = 0 }

[[vader.displays]]
output     = "DP-2"
width      = 2560
height     = 2880
workspaces = [3, 4, 5, 6]
position   = { x = 2560, y = 0 }

[[vader.displays]]
output     = "DP-3"
width      = 1920
height     = 1080
workspaces = [10]
position   = { x = 320, y = 2880 }
```

### `noughty.host.display` - Derived display shortcuts (read-only)

All derived from `noughty.host.displays`. Primary is the first display where `primary == true`, or the first in the list if none is marked primary, or `null` if no displays are configured.

| Option | Type | Description |
|--------|------|-------------|
| `display.primary` | `nullOr attrs` | The primary display attrset. |
| `display.primaryOutput` | `str` | Output connector name of the primary display. `""` if none. |
| `display.primaryWidth` | `int` | Horizontal resolution. `0` if none. |
| `display.primaryHeight` | `int` | Vertical resolution. `0` if none. |
| `display.primaryResolution` | `str` | Formatted `"WIDTHxHEIGHT"`. `""` if none. |
| `display.primaryOrientation` | `enum ["landscape" "portrait"]` | Derived from width vs height. |
| `display.primaryIsPortrait` | `bool` | `height > width`. |
| `display.primaryIsUltrawide` | `bool` | Aspect ratio >= 21:10. |
| `display.primaryScale` | `float` | Scale factor of the primary display. `1.0` if none. |
| `display.primaryIsHighDpi` | `bool` | `scale >= 2.0`. |
| `display.primaryIsHighRes` | `bool` | Pixel count >= ~QHD+ (3,686,400 pixels). |
| `display.isMultiMonitor` | `bool` | `length displays > 1`. |
| `display.outputs` | `listOf str` | All output connector names. |

### `noughty.host.keyboard` - Keyboard layout and locale

Keyboard layout is set once in the registry and derived into the formats each subsystem requires. Defaults to `"gb"` (United Kingdom) so the vast majority of hosts need not set anything.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `keyboard.layout` | `str` | `"gb"` | XKB keyboard layout code. Used by `services.xserver.xkb.layout`, Hyprland `kb_layout`, Wayfire `xkb_layout`, and kmscon. |
| `keyboard.variant` | `str` | `""` | XKB variant (e.g. `"dvorak"`, `"colemak"`). Empty string means the default variant. |
| `keyboard.consoleKeymap` | `str` | *(read-only, derived)* | Linux console keymap name, derived from `layout`. Used by `console.keyMap`. `"gb"` maps to `"uk"`; most other codes are identical in both namespaces. |
| `keyboard.locale` | `str` | *(derived, overridable)* | POSIX locale string derived from `layout` (e.g. `"gb"` -> `"en_GB.UTF-8"`). Used by `i18n.defaultLocale` and all `LC_*` settings. Override explicitly when locale and layout diverge. |

#### Format divergence: XKB vs console keymap

The Linux virtual console and the XKB subsystem use different naming conventions for the same physical layout. The most common divergence is the British layout:

| Subsystem | Option | Value |
|-----------|--------|-------|
| XKB (xserver, Hyprland, Wayfire, kmscon) | `keyboard.layout` | `"gb"` |
| Linux console | `keyboard.consoleKeymap` | `"uk"` |
| POSIX locale | `keyboard.locale` | `"en_GB.UTF-8"` |
| macOS NSGlobalDomain | derived | `"en_GB"` / `"en-GB"` |

The `consoleKeymap` option is read-only and derives automatically. Modules read `host.keyboard.consoleKeymap` for `console.keyMap` and `host.keyboard.layout` for everything XKB-based.

#### Registry usage

Since `"gb"` is the default, no registry entry is needed for UK hosts. Only non-UK hosts set `keyboard`:

```nix
# lib/registry-systems.nix - a US host (minimal)
zuul = {
  kind = "computer";
  platform = "x86_64-linux";
  keyboard.layout = "us";
  # consoleKeymap auto-derives to "us", locale to "en_US.UTF-8"
};

# A host where locale and layout diverge (Swiss German)
helvetia = {
  kind = "computer";
  platform = "x86_64-linux";
  keyboard = {
    layout = "ch";
    locale = "de_CH.UTF-8";  # override - cannot auto-derive from "ch" alone
  };
};
```

#### Usage in modules

```nix
{ config, ... }:
let
  inherit (config.noughty) host;
in
{
  console.keyMap                = host.keyboard.consoleKeymap;  # "uk"
  services.xserver.xkb.layout  = host.keyboard.layout;         # "gb"
  i18n.defaultLocale            = host.keyboard.locale;         # "en_GB.UTF-8"

  wayland.windowManager.hyprland.settings.input.kb_layout = host.keyboard.layout;
}
```

### `noughty.user` - User identity

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `user.name` | `str` | `"nobody"` | Primary username of the managed system. |
| `user.tags` | `listOf str` | `[]` | Freeform tags for user role or persona classification. |

### `noughty.network` - Network attributes

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `network.tailNet` | `str` | `"drongo-gamma.ts.net"` | Tailscale network domain. |

### Tags

Tags are freeform `listOf str`. The canonical vocabulary is documented in a comment block in `lib/registry-systems.toml`:

- **Host tags:** `streamstation`, `trackball`, `streamdeck`, `pci-hdmi-capture`, `thinkpad`, `policy`, `steamdeck`, `lima`, `wsl`, `inference`
- **User tags:** `developer`, `admin`, `family`

Tags centralise classification that was previously scattered as hostname comparisons across the tree (e.g. `hostname == "phasma" || hostname == "vader"` becomes the `"streamstation"` tag, set once in the registry).

Because `tags` is `listOf str`, values from the registry and host-specific modules merge automatically via the module system. Tags are for *classification* ("this host is a streamstation"), not *configuration* ("this host uses DP-1").

Start simple; add enum validation only if typos become a real problem.

## Helper function reference

All helpers are accessed as `noughtyLib.<name>` in any module. `noughtyLib` is injected via `_module.args`, so it is available as a named argument like `lib` or `pkgs`. No `config` import is needed solely for helper access.

| Helper | Signature | Description |
|--------|-----------|-------------|
| `isUser` | `[str] -> bool` | Current user is in the list. |
| `isHost` | `[str] -> bool` | Current host is in the list. |
| `hostNameCapitalised` | `str` | Hostname with first letter capitalised (e.g. `"vader"` -> `"Vader"`). |
| `hostHasTag` | `str -> bool` | Host has the given tag. |
| `userHasTag` | `str -> bool` | User has the given tag. |
| `hostHasTags` | `[str] -> bool` | Host has *all* listed tags. |
| `userHasTags` | `[str] -> bool` | User has *all* listed tags. |
| `hostHasAnyTag` | `[str] -> bool` | Host has *at least one* listed tag. |
| `userHasAnyTag` | `[str] -> bool` | User has *at least one* listed tag. |

All closures capture `hostName`, `userName`, `hostTags`, and `userTags` from `config.noughty.*` at evaluation time.

## Usage patterns

### Flat pattern (95% of modules, no `imports`)

Most modules are leaf modules with no `imports`. Use `lib.mkIf condition { ... }` as the entire module body.

#### User-gated

```nix
{ noughtyLib, lib, pkgs, ... }:
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home.packages = [ pkgs.zed-editor ];
}
```

#### Tag-gated

```nix
{ noughtyLib, lib, ... }:
lib.mkIf (noughtyLib.hostHasTag "streamstation") {
  services.foo.enable = true;
}
```

#### Boolean flags

```nix
{ config, lib, ... }:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.workstation {
  boot.plymouth.enable = true;
}
```

#### GPU-gated

```nix
{ config, lib, ... }:
let
  gpu = config.noughty.host.gpu;
in
{
  hardware.nvidia-container-toolkit.enable = gpu.hasNvidia;
}
```

#### Display-dependent

```nix
{ config, ... }:
let
  display = config.noughty.host.display;
in
{
  monitor = display.primaryOutput;
  resolution = display.primaryResolution;
}
```

#### Combined conditions

```nix
{ config, noughtyLib, lib, ... }:
lib.mkIf (noughtyLib.isUser [ "martin" ] && config.noughty.host.is.workstation) {
  # User + workstation gated config
}
```

#### Inference/VRAM-tier (real-world example from ollama)

```nix
{ config, lib, noughtyLib, pkgs, ... }:
let
  inherit (config.noughty) host;
  vram = host.gpu.compute.vram;
  accel = host.gpu.compute.acceleration;
  ollamaPackage =
    if accel == "cuda" then pkgs.ollama-cuda
    else if accel == "rocm" then pkgs.ollama-rocm
    else pkgs.ollama;
in
lib.mkIf (noughtyLib.hostHasTag "inference") {
  services.ollama = {
    enable = true;
    package = ollamaPackage;
    host = if host.is.server then "0.0.0.0" else "127.0.0.1";
  };
}
```

### Long-form pattern (hub modules with `imports`)

See the dedicated section below.

## The long-form `config = lib.mkIf` pattern

This is the most important pattern to understand when working with Noughty and `imports`.

### Decision rule: does the module have `imports`?

- **No `imports`** - use the flat pattern. `lib.mkIf condition { ... }` as the entire module body. This covers ~95% of modules.
- **Has `imports`** - use the long-form pattern. `{ imports = [...]; config = lib.mkIf condition { ... }; }`. Imports stay unconditional; each imported sub-module gates itself.

That is it. One question, one answer.

### Why this matters

The Nix module system evaluates in two passes:

1. **First pass:** collect all `imports` to build the complete module tree.
2. **Second pass:** evaluate `config` by merging all modules.

Since `imports` are resolved *before* `config` exists, an expression like this causes infinite recursion:

```nix
# BROKEN - do not do this
imports = lib.optional config.noughty.host.is.workstation ./foo;
```

It needs `config` to determine imports, but needs imports to determine `config`.

The long-form pattern sidesteps this: `imports` are always unconditional (resolved in pass one), and `config` is gated with `lib.mkIf` (evaluated in pass two). A module whose entire `config` is `lib.mkIf false { ... }` is fully evaluated but contributes nothing to the system configuration.

### Example: hub module

```nix
{ config, lib, ... }:
{
  imports = [ ./hyprland ./wayfire ];
  config = lib.mkIf config.noughty.host.is.workstation {
    boot.plymouth.enable = true;
  };
}
```

Each imported sub-module gates itself internally:

```nix
# ./hyprland/default.nix
{ config, lib, ... }:
lib.mkIf (config.noughty.host.desktop == "hyprland") {
  # Hyprland-specific config
}
```

### Important subtlety: `let` bindings inside the gate

When a hub module has `let` bindings that depend on `config.noughty.*` values (e.g. reading `desktop`, which is `null` on non-workstation systems), place the `let` block *inside* the `config` gate to avoid evaluation failures:

```nix
{ config, lib, ... }:
{
  imports = [ ./hyprland ./wayfire ];
  config = lib.mkIf config.noughty.host.is.workstation (
    let
      desktop = config.noughty.host.desktop;
    in
    {
      # Config using desktop safely - only evaluated when gate is true
    }
  );
}
```

Nix's laziness means bindings inside a false `lib.mkIf` are not forced. But a `let` block *outside* the gate that unconditionally calls a function on `desktop` (which is `null` for non-workstation systems) would produce a type error when that host evaluates.

Only ~6 hub modules in the codebase need this pattern. Adding a new leaf mixin (the common case) never requires it.

## CLI tool

The `noughty` command is a shell script wrapped via `writeShellApplication` that bakes `config.noughty.*` values into shell variables at build time. Located in `home-manager/_mixins/scripts/noughty/`.

### Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `noughty facts` | `nofx` | Show system attributes and configuration. |
| `noughty path <executable>` | `nook` | Show Nix store path for an executable. |
| `noughty run [--unstable] <package>` | `nout` | Run a package from nixpkgs. |
| `noughty shell [--unstable] <pkg...>` | `nosh` | Spawn a shell with packages from nixpkgs. |
| `noughty channel` | `norm` | Show current stable nixpkgs channel. |
| `noughty spawn <program> [args...]` | `nope` | Launch a program detached from the session. |

### Example output

```
  nøughty facts

  Host         vader
  Kind         computer
  OS           linux (x86_64-linux)
  Form         desktop
  Desktop      hyprland
  GPU          amd, nvidia
  Compute      nvidia (16GB) [cuda]
  Tags         streamstation, trackball, streamdeck, pci-hdmi-capture, inference

  User         martin
  Tailnet      drongo-gamma.ts.net

  Displays     DP-1, DP-2, DP-3
  Primary      DP-1 (2560x2880)

  Flags        workstation, linux
```

### How it works

The `default.nix` wrapper reads `config.noughty.*` at build time and prepends shell variable assignments (e.g. `NOUGHTY_HOST_NAME="vader"`) to the script source. The shell script then uses these variables to format output and drive subcommands. No runtime evaluation of Nix expressions is needed.

## What stays as specialArgs

Only four values remain in `specialArgs`/`extraSpecialArgs`, consistent across all three systems:

| Value | Reason |
|-------|--------|
| `inputs` | Flake inputs are not configuration. Modules need them to reference other flakes. |
| `outputs` | Same as `inputs`. |
| `stateVersion` | Simple scalar for system/home stateVersion. No benefit from being an option. |
| `catppuccinPalette` | Complex attrset with functions. Self-contained and consistently available. Out of scope. |

`hostname` and `username` were fully eliminated from `specialArgs` during the migration. All module bodies read `config.noughty.host.name` and `config.noughty.user.name`.

## Adding a new host

### 1. Add to the system registry in `lib/registry-systems.toml`

```toml
# lib/registry-systems.toml
[mynewhost]
kind       = "computer"    # or "server", "vm", "container"
platform   = "x86_64-linux"
formFactor = "desktop"     # or "laptop", "handheld", null (omit for none)
tags       = ["thinkpad"]  # if applicable

[mynewhost.gpu]
vendors = ["amd"]          # if applicable

[[mynewhost.displays]]
output     = "DP-1"
width      = 2560
height     = 1440
refresh    = 144
primary    = true
workspaces = [1, 2, 3, 4, 5]
position   = { x = 0, y = 0 }

# desktop defaults to "hyprland" for computer+linux
# username defaults to "martin"
# keyboard defaults to "gb" (UK); set keyboard.layout = "us" for non-UK hosts
```

### 2. Create host directory

Create `nixos/mynewhost/default.nix` with hardware-specific configuration (disk layout, kernel modules, nixos-hardware imports):

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" ];
}
```

### 3. Build and verify

```bash
nix build .#nixosConfigurations.mynewhost.config.system.build.toplevel
```

No other files need updating. The registry entry flows through `resolveEntry` -> `mkSystemConfig` -> `mkNixos`/`mkHome` -> `noughty.*` options automatically.

### Default resolution

When you add a new host, `resolveEntry` in `lib/flake-builders.nix` merges defaults in this order:

1. `username = "martin"` (baseline)
2. `desktop` derived from `kind` + platform (e.g. `computer` on Linux -> `"hyprland"`)
3. If `iso = true`: `desktop = null`, `username = "nixos"`
4. Explicit values from your registry entry (always win)

## Extending the module

### Adding a new option

Add the option declaration to `lib/noughty/default.nix`:

```nix
options.noughty.host.myNewOption = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Description of what this option controls.";
};
```

If it should be set from the registry, also:

1. Add the field to registry entries in `lib/registry-systems.toml`.
2. Pass it through `mkSystemConfig` in `lib/flake-builders.nix`.
3. Set it in the `noughty.host` block within `mkNixos`/`mkHome`/`mkDarwin`.

### Adding a new helper function

Add the function to `lib/noughty-helpers.nix`:

```nix
{
  # ... existing helpers ...
  myNewHelper = someArg: lib.someFunction someArg hostTags;
}
```

The function has access to `hostName`, `userName`, `hostTags`, and `userTags` via the closure.

### Adding a new tag

1. Add the tag to the canonical vocabulary comment in `lib/registry-systems.toml`.
2. Set the tag on relevant hosts in the registry.
3. Use `noughtyLib.hostHasTag "my-new-tag"` in modules.

## Design decisions

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| Module, not better helpers | NixOS options module | Module system provides type checking, defaults, overridability, and documentation. |
| `_module.args` for noughtyLib | Not `specialArgs` | Preserves lazy closure over `config.noughty.*`. Overrides via `mkForce` are reflected. |
| Tags are freeform strings | `listOf str`, not enum | Start simple. Canonical vocabulary documented in `lib/registry-systems.toml`. Add validation only if typos become a real problem. |
| GPU uses structured options | Not tags | Distinguishes vendors on dual-GPU hosts. Enum list with derived booleans provides type validation. |
| Displays in registry | `lib/registry-systems.toml` | Display data must flow to standalone Home Manager contexts. Extracting the registry to a dedicated file resolved the verbosity concern. |
| `host.kind` replaces `type` | `enum ["computer" "server" "vm" "container"]` | Separates system class from OS, use-case, and deployment mechanism. |
| `is.laptop` from `formFactor` | Not negative hostname list | Adding a new laptop just requires `formFactor = "laptop"`. No other files to update. |
| `hasCuda` from `compute.acceleration` | Not vendor presence | A host with NVIDIA for encoding but no compute block correctly reports `hasCuda = false`. |
| `hostname`/`username` eliminated from specialArgs | Read from `config.noughty.*` | All module bodies use `config.noughty.host.name` and `config.noughty.user.name`. |
| `keyboard` uses structured options | Not hardcoded strings in each module | Single source of truth for layout, with derived `consoleKeymap` and `locale`. `"gb"` default means UK hosts need zero configuration. |
| Registries use TOML, not Nix | `builtins.fromTOML` (stable since Nix 2.3) | Noughty Linux users should not need Nix knowledge to manage host entries. TOML is widely familiar, parseable by non-Nix tooling, and produces an identical attrset structure via `builtins.fromTOML` - no downstream code changed. |
