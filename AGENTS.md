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
just iso console                    # Build minimal console ISO
just update                         # Update flake.lock
just gc                             # Clean old generations, keep latest 5
```

## Code style and conventions

**Language:**

- British English spelling throughout all documentation and code
- Comments use full sentences with proper punctuation

**File structure:**

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
- Functions: camelCase in `lib/helpers.nix`

**Nix style:**

- Use `nixfmt-rfc-style` formatter (run via `nix fmt`)
- Prefer `lib.mkDefault` and `lib.mkForce` over plain values for overridability
- Use `lib.optional` and `lib.optionals` for conditional imports
- Explicit `inherit` statements for clarity
- String interpolation: `"${variable}"` not `variable`

**Mixin placement:**

- System-level services, kernel, boot, networking → `nixos/_mixins/`
- User-level programs, dotfiles, scripts → `home-manager/_mixins/`
- Hardware-specific config (disks, kernel modules) → `nixos/{hostname}/`
- Use `home.packages` in Home Manager modules, `environment.systemPackages` in NixOS modules

## System registry and configuration

All systems defined in `flake.nix` system registry with type-based defaults:

- **type**: `workstation`, `server`, `vm`, `darwin`, `lima`, `iso`, `wsl`, `gaming`
- **username**: defaults based on type (martin/nixos/deck)
- **platform**: `x86_64-linux`, `aarch64-darwin`
- **desktop**: `hyprland`, `wayfire`, `aqua`, or `null`

Helper functions in `lib/helpers.nix` generate configs from registry.

## Special arguments

These are passed to all modules via `specialArgs`:

- `hostname`: system hostname
- `username`: primary user
- `desktop`: desktop environment or null
- `platform`: system architecture
- `stateVersion`: NixOS/Home Manager state version (defined in `lib/helpers.nix`)
- `isWorkstation`, `isLaptop`, `isServer`, `isLima`, `isISO`, `isInstall`: boolean flags
- `catppuccinPalette`: colour palette helper with `getColor`, `getHyprlandColor`, etc.
- `inputs`, `outputs`: flake inputs and outputs

Access in modules:

```nix
{ hostname, username, catppuccinPalette, lib, ... }:
{
  # Use hostname, username, or palette colours
}
```

## Secrets management

Secrets encrypted with sops-nix using age keys.

- **User key:** `~/.config/sops/age/keys.txt`
- **Host key:** `/var/lib/private/sops/age/keys.txt`
- **Edit secrets:** `sops secrets/secrets.yaml` or `sops secrets/host-{hostname}.yaml`
- **Rekey after adding recipients:** `sops updatekeys secrets/secrets.yaml`
- Never commit unencrypted secrets. All sensitive data in encrypted `.yaml` files in `secrets/`.

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

Add to system registry in `flake.nix`:

```nix
systems = {
  mynewhost = {
    type = "workstation";  # or server, vm, darwin, etc.
    desktop = "hyprland";  # or null, wayfire, aqua
    # username and platform use type defaults
  };
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

  # Hardware-specific configuration
}
```

Create disk layout with Disko in `nixos/mynewhost/disks.nix`. Build with:

```bash
nix build .#nixosConfigurations.mynewhost.config.system.build.toplevel
```

## CI/CD workflows

Unified CI workflow in `.github/workflows/ci.yml` triggers on pull requests and pushes to main:

1. **Inventory** - `flake-inventory.sh` discovers all buildable outputs, emitting per-platform JSON matrices
2. **Build jobs** - Parallel per-host/per-package builds using `flake-build.sh` (devShells, packages, NixOS, Darwin, orphan Home Manager configs)
3. **Publish** - Pushes to FlakeHub with `include-output-paths: true` for FlakeHub Cache
4. **Release ISO** - Builds and publishes console ISO on main branch

Auto-merge of `flake.lock` update PRs is gated on all build jobs passing via branch protection required status checks.

## Architecture notes

**Mixin pattern:**

Configurations composed from small, focused modules in `_mixins` directories. Each mixin handles one concern (e.g., desktop environment, hardware feature, script). Mixins imported based on system type and flags.

**Helper function flow:**

1. System registry in `flake.nix` defines all hosts
2. `generateConfigs` filters by type and merges with type defaults
3. `mkNixos`, `mkHome`, `mkDarwin` create final configurations
4. Special args computed and passed to all modules
5. Modules import relevant mixins based on flags

**Overlay system:**

- `localPackages`: Custom packages from `pkgs/` directory
- `modifiedPackages`: Overrides and patches to nixpkgs packages
- `unstablePackages`: Access to nixpkgs-unstable via `pkgs.unstable`

Applied in order, allowing layered modifications.

## Common issues and solutions

**Build fails with "infinite recursion":**

- Check for circular imports in mixin modules
- Verify `specialArgs` are not redeclared in module arguments

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
- Run `just eval` before committing Nix changes to catch evaluation errors
- Run `just build` or `just build-host` / `just build-home` to verify builds before switching
- Keep each mixin self-contained with a single concern
