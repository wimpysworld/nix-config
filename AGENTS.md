# AGENTS.md

## Project overview

NixOS, nix-darwin, and Home Manager flake for managing multiple systems declaratively. Uses mixin pattern for composable configuration modules. Builds workstations, servers, VMs, macOS systems, and custom ISO images.

## Build and deploy commands

Build and switch system configuration:

```bash
just host              # Build and switch NixOS/nix-darwin config
just home              # Build and switch Home Manager config
just switch            # Switch both system and home (runs home first, then host)
```

Apply pre-built configurations from FlakeHub Cache (no local evaluation):

```bash
just apply             # Apply both system and home from FlakeHub Cache
just apply-home        # Apply Home Manager only
just apply-host        # Apply NixOS/nix-darwin only
```

Build only (no switch):

```bash
just build-host        # Build NixOS/nix-darwin only
just build-home        # Build Home Manager only
just build             # Build both (runs home first, then host)
```

Validate configurations:

```bash
just check             # Run nix flake check with trace
just eval              # Evaluate flake syntax and all configurations
just eval-flake        # Evaluate flake structure only
just eval-configs      # Evaluate all system configurations
```

Other commands:

```bash
just build-pkg firefox              # Build package for current host
just build-pkg firefox vader        # Build package for specific host
just iso                            # Build nihilus ISO image
just update                         # Update flake.lock
just gc                             # Clean old generations, keep latest 5
```

Install and deploy:

```bash
just install vader 192.168.1.10     # Remote install via nixos-anywhere
just inject-tokens 192.168.1.10     # Inject tokens to ISO host for install
```

`just install` handles SOPS age key injection, SSH host key decryption, and LUKS password/keyfile setup. Optional parameters: `keep_disks="true"`, `vm_test="true"`. `just inject-tokens` sends user age key and host age key to the target. Optional parameter: `user="nixos"`.

## Code style and conventions

**Language:**

- British English spelling throughout all documentation and code
- Comments use full sentences with proper punctuation

**File structure:**

- Shared cross-platform configuration in `common/default.nix`, imported by both NixOS and nix-darwin
- Configuration organised in `_mixins` directories using mixin pattern
- Each mixin is self-contained with `default.nix` entry point
- Host-specific configs in `nixos/{hostname}/`, `darwin/{hostname}/`
- Custom packages in `pkgs/` directory, exposed via overlay

**Shell scripts:**

- All scripts use `pkgs.writeShellApplication` wrapper (provides shellcheck validation)
- Scripts live in `nixos/_mixins/scripts/` or `home-manager/_mixins/scripts/`
- Each script in separate directory: `script-name/default.nix` + `script-name.sh`
- Runtime dependencies declared in `runtimeInputs` list
- Template available at `home-manager/_mixins/scripts/_template/`

**Naming conventions:**

- Hostnames: Sith Lords (workstations/servers), TIE fighters (VMs)
- Variables: camelCase for Nix attributes
- Files: kebab-case for directories and Nix files
- Functions: camelCase in `lib/flake-builders.nix`

**Nix style:**

- Use `nixfmt` formatter (run via `nix fmt`)
- Prefer `lib.mkDefault` and `lib.mkForce` over plain values for overridability
- Use `lib.optional` and `lib.optionals` for conditional imports
- Explicit `inherit` statements for clarity
- String interpolation: `"${variable}"` not `variable`

**Module shorthand convention:**

- Use `inherit (config.noughty) host;` in `let` bindings (NOT `cfg`)
- Then reference `host.is.workstation`, `host.desktop`, `host.name`, etc.

**Mixin placement:**

- System-level services, kernel, boot, networking → `nixos/_mixins/`
- User-level programs, dotfiles, scripts → `home-manager/_mixins/`
- Hardware-specific config (disks, kernel modules) → `nixos/{hostname}/`
- Use `home.packages` in Home Manager modules, `environment.systemPackages` in NixOS modules

## System registry and configuration

All systems defined in `lib/registry-systems.nix` (imported by `flake.nix`). Each entry specifies:

- **kind** (required): `"computer"`, `"server"`, `"vm"`, `"container"`
- **platform** (required): `"x86_64-linux"`, `"aarch64-darwin"`, etc.
- **formFactor** (optional): `"laptop"`, `"desktop"`, `"handheld"`, `"tablet"`, `"phone"`
- **desktop** (optional): derived from `kind` + platform if omitted (e.g. `computer` on Linux defaults to `"hyprland"`, Darwin defaults to `"aqua"`)
- **username** (optional): defaults to `"martin"`
- **gpu** (optional): `{ vendors = [ "amd" "nvidia" ]; compute = { vendor = "nvidia"; vram = 16; }; }`
- **displays** (optional): list of display submodules with output, width, height, refresh, scale, position, primary, workspaces
- **tags** (optional): `[ "streamstation" "thinkpad" "iso" ... ]`

Users defined in `lib/registry-users.nix` (imported by `flake.nix`):

```nix
# In lib/registry-users.nix
{
  martin = { tags = [ "developer" ]; };
}
```

ISO hosts use `tags = [ "iso" ]` which applies implicit defaults (`desktop = null`, `username = "nixos"`). The ISO host is `nihilus`.

Helper functions in `lib/flake-builders.nix` generate configs from the registry. `resolveEntry` merges four layers: baseline username, kind+OS derived desktop, ISO implicit defaults, then explicit entry values.

## Noughty module system

All host/user metadata is accessed via `config.noughty.*` options, not `specialArgs`. The noughty module provides type checking, defaults, and `mkDefault`/`mkForce` overridability.

Only four values remain in `specialArgs`:

- `inputs`, `outputs`: flake inputs and outputs
- `stateVersion`: NixOS/Home Manager state version
- `catppuccinPalette`: colour palette helper

Access host/user data in modules:

```nix
{ config, noughtyLib, lib, ... }:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.workstation {
  # host.name, host.desktop, host.is.laptop, host.gpu.hasNvidia, etc.
}
```

Use `noughtyLib` helpers for tag and identity checks:

```nix
{ noughtyLib, lib, pkgs, ... }:
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home.packages = [ pkgs.zed-editor ];
}
```

Key gating patterns:

- `host.is.workstation`, `host.is.server`, `host.is.laptop`, `host.is.iso`, `host.is.vm`, `host.is.darwin`, `host.is.linux` - derived booleans
- `noughtyLib.isUser [ "martin" ]` - user identity check
- `noughtyLib.isHost [ "vader" "phasma" ]` - host identity check
- `noughtyLib.hostHasTag "streamstation"` - host tag check
- `noughtyLib.userHasTag "developer"` - user tag check
- `host.gpu.hasNvidia`, `host.gpu.hasCuda` - GPU checks
- `host.display.primaryOutput`, `host.display.isMultiMonitor` - display checks

See `lib/noughty/README.md` for the complete option reference and usage patterns.

## Secrets management

Secrets encrypted with sops-nix using age keys.

- **User key:** `~/.config/sops/age/keys.txt`
- **Host key:** `/var/lib/private/sops/age/keys.txt`
- **Edit secrets:** `sops secrets/secrets.yaml` or `sops secrets/host-{hostname}.yaml`
- **Rekey after adding recipients:** `sops updatekeys secrets/secrets.yaml`
- Never commit unencrypted secrets. All sensitive data in encrypted `.yaml` files in `secrets/`.

For ISO installs, `just inject-tokens` sends age keys to the ISO media at `/tmp/injected-tokens/`. Both user and host age keys are hard requirements for `install-system` (hard stop if missing). FlakeHub Cache is auto-detected: `install-system` checks `determinate-nixd status` and prompts the user to run `determinate-nixd login` interactively if not already authenticated; otherwise falls back to local build.

## Catppuccin theming

Catppuccin Mocha palette available via `catppuccinPalette` helper:

```nix
{ catppuccinPalette, ... }:
{
  # Get hex colour with #
  backgroundColor = catppuccinPalette.getColor "base";

  # Get hex without # (for Hyprland)
  hyprlandColor = catppuccinPalette.getHyprlandColor "blue";

  # Access raw palette
  palette = catppuccinPalette.colors;

  # Theme detection
  isDark = catppuccinPalette.isDark;        # true for mocha
  preferShade = catppuccinPalette.preferShade;  # "prefer-dark"
}
```

Available colours: base, mantle, crust, surface0, surface1, surface2, overlay0, overlay1, overlay2, subtext0, subtext1, text, lavender, blue, sapphire, sky, teal, green, yellow, peach, maroon, red, mauve, pink, flamingo, rosewater.

## Adding new packages

Create `pkgs/my-package/default.nix`:

```nix
{ lib, stdenv, fetchurl, ... }:

stdenv.mkDerivation rec {
  pname = "my-package";
  version = "1.0.0";

  src = fetchurl {
    url = "https://example.com/${pname}-${version}.tar.gz";
    sha256 = lib.fakeSha256;  # Build once to get real hash
  };

  meta = with lib; {
    description = "Package description";
    homepage = "https://example.com";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
```

Add to `pkgs/default.nix`:

```nix
{
  my-package = pkgs.callPackage ./my-package { };
}
```

Reference in configuration:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.my-package ];
}
```

## Adding shell scripts

Use template from `home-manager/_mixins/scripts/_template/`:

```bash
cp -r home-manager/_mixins/scripts/_template home-manager/_mixins/scripts/my-script
mv home-manager/_mixins/scripts/my-script/template.sh home-manager/_mixins/scripts/my-script/my-script.sh
```

Edit `my-script.sh` with your script logic. Edit `default.nix` to declare runtime dependencies:

```nix
{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [ curl jq ];  # Add dependencies here
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home.packages = [ shellApplication ];
}
```

Script automatically validated with shellcheck during build.

## Creating new system configuration

Add to system registry in `lib/registry-systems.nix`:

```nix
# In lib/registry-systems.nix
mynewhost = {
  kind = "computer";        # or "server", "vm", "container"
  platform = "x86_64-linux";
  formFactor = "desktop";   # or "laptop", "handheld", null
  gpu.vendors = [ "amd" ];  # if applicable
  tags = [ "thinkpad" ];    # if applicable
  displays = [
    { output = "DP-1"; width = 2560; height = 1440; refresh = 144; primary = true; workspaces = [ 1 2 3 4 5 ]; }
  ];
  # desktop defaults to "hyprland" for computer+linux
  # username defaults to "martin"
};
```

Create host directory and `nixos/mynewhost/default.nix`:

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

Create disk layout with Disko in `nixos/mynewhost/disks.nix`. Build with:

```bash
nix build .#nixosConfigurations.mynewhost.config.system.build.toplevel
```

No other files need updating. The registry entry flows through `resolveEntry` -> `mkSystemConfig` -> `mkNixos`/`mkHome` -> `noughty.*` options automatically.

## CI/CD workflows

Three workflows in `.github/workflows/`:

- **`builder.yml`** - Triggers on pull requests and pushes to main:
  1. **Inventory** - `flake-inventory.sh` discovers all buildable outputs, emitting per-platform JSON matrices
  2. **Build jobs** - Parallel per-host/per-package builds using `flake-build.sh` (devShells, packages, NixOS, Darwin, orphan Home Manager configs)
  3. **Publish** - Pushes to FlakeHub with `include-output-paths: true` for FlakeHub Cache
  4. **Release ISO** - Builds and publishes the nihilus ISO on main branch

- **`updater.yml`** - Scheduled `flake.lock` updates via PR
- **`checker.yml`** - Scheduled flake lock health checks

Auto-merge of `flake.lock` update PRs is gated on all build jobs passing via branch protection required status checks.

## Architecture notes

**Mixin pattern:**

Configurations composed from small, focused modules in `_mixins` directories. Each mixin handles one concern (e.g., desktop environment, hardware feature, script). Mixins gate themselves using `config.noughty.*` conditions.

**Configuration flow:**

1. System registry in `lib/registry-systems.nix` and `lib/registry-users.nix` defines all hosts and users
2. `resolveEntry` in `lib/flake-builders.nix` merges registry defaults (baseline, kind+OS derived, ISO defaults, explicit values)
3. `mkSystemConfig` produces the attribute set consumed by `mkNixos`, `mkHome`, `mkDarwin`
4. `noughty.*` options are set in the modules list; `lib/noughty/default.nix` computes derived booleans
5. `_module.args.noughtyLib` provides convenience helpers to all modules
6. `common/default.nix` provides shared configuration (documentation, nixpkgs, nix registry, common packages, environment variables, fish shell) imported by both `nixos/default.nix` and `darwin/default.nix`
7. Platform-specific entry points add their own imports, packages and settings
8. Modules gate themselves using `config.noughty.*` or `noughtyLib.*`

**Module gating patterns:**

- **Flat pattern** (~95% of modules): `lib.mkIf condition { ... }` as the entire module body
- **Long-form pattern** (hub modules with `imports`): `{ imports = [...]; config = lib.mkIf condition { ... }; }` - imports stay unconditional, each sub-module gates itself
- Never use `lib.optional config.noughty.* ./foo` in `imports` - causes infinite recursion

See `lib/noughty/README.md` for detailed explanation of the long-form pattern.

**Overlay system:**

- `localPackages`: Custom packages from `pkgs/` directory
- `modifiedPackages`: Overrides and patches to nixpkgs packages
- `unstablePackages`: Access to nixpkgs-unstable via `pkgs.unstable`

Applied in order, allowing layered modifications.

## Common issues and solutions

**Build fails with "infinite recursion":**

- Check for `config.noughty.*` used inside `imports` (must be in `config` block, not `imports`)
- Check for circular imports in mixin modules

**Home Manager activation fails:**

- Ensure Home Manager configuration doesn't conflict with NixOS
- Check file ownership and permissions
- Use `home-manager switch -b backup --flake .` to backup conflicting files

**Secrets not accessible:**

- Verify age keys exist at specified locations
- Check recipients in `.sops.yaml` match public keys
- Run `sops updatekeys` after editing recipients

**Package not found:**

- Verify package added to `pkgs/default.nix`
- Check overlay applied in configuration
- Search nixpkgs: `nix search nixpkgs <package-name>`

**Shell script fails shellcheck:**

- Use `pkgs.writeShellApplication` wrapper (not `writeShellScriptBin`)
- Add necessary runtime dependencies to `runtimeInputs`
- Fix shellcheck warnings (shellcheck validation automatic)

## Constraints

- Never modify `flake.lock` directly; use `just update`
- Never change `stateVersion` on existing systems (breaks compatibility)
- Never commit unencrypted secrets outside `secrets/` directory
- Never use `environment.systemPackages` in Home Manager modules; use `home.packages`
- Never use `writeShellScriptBin`; use `writeShellApplication` (enforces shellcheck)
- Never use `config.noughty.*` inside `imports` - causes infinite recursion; use the long-form `config = lib.mkIf` pattern instead
- Run `just eval` before committing Nix changes to catch evaluation errors
- Run `just build` or `just build-host` / `just build-home` to verify builds before switching
- Keep each mixin self-contained with a single concern
