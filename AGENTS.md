# AGENTS.md

## Project overview

NixOS, nix-darwin, and Home Manager flake for managing multiple systems declaratively. Uses mixin pattern for composable configuration modules. Builds workstations, servers, VMs, macOS systems, and custom ISO images.

## Setup commands

Clone to standard location:

```bash
gh repo clone wimpysworld/nix-config ~/Zero/nix-config
cd ~/Zero/nix-config
```

Enter development shell (automatically via direnv if installed):

```bash
nix develop
```

## Build and test commands

Build and switch system configuration:

```bash
just host              # Build and switch NixOS/nix-darwin config
just home              # Build and switch Home Manager config
just switch            # Switch both system and home (runs home first, then host)
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

Build specific package:

```bash
just build-pkg firefox              # Build package for current host
just build-pkg firefox vader        # Build package for specific host
```

Build ISO image:

```bash
just iso console       # Build minimal console ISO
```

Update dependencies:

```bash
just update            # Update flake.lock
```

Garbage collection:

```bash
just gc                # Clean old generations, keep latest 5
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

## System registry and configuration

All systems defined in `flake.nix` system registry with type-based defaults:

- **type**: `workstation`, `server`, `vm`, `darwin`, `lima`, `iso`, `wsl`, `gaming`
- **username**: defaults based on type (martin/nixos/deck)
- **platform**: `x86_64-linux`, `aarch64-darwin`, etc.
- **desktop**: `hyprland`, `wayfire`, `aqua`, or `null`

Helper functions in `lib/helpers.nix` generate configs from registry.

## Special arguments

These are passed to all modules via `specialArgs`:

- `hostname`: system hostname
- `username`: primary user
- `desktop`: desktop environment or null
- `platform`: system architecture
- `stateVersion`: NixOS/Home Manager state version (25.11)
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

## Testing locally

Test configuration changes without switching:

```bash
just build-host        # Verify NixOS/nix-darwin builds
just build-home        # Verify Home Manager builds
just eval-configs      # Check for evaluation errors
```

Build specific system:

```bash
nix build .#nixosConfigurations.vader.config.system.build.toplevel
nix build .#homeConfigurations."martin@vader".activationPackage
nix build .#darwinConfigurations.momin.config.system.build.toplevel
```

## Secrets management

Secrets encrypted with sops-nix using age keys.

**User key location:** `~/.config/sops/age/keys.txt`
**Host key location:** `/var/lib/private/sops/age/keys.txt`

Generate user key:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt  # Display public key
```

Generate host key (on target system):

```bash
sudo mkdir -p /var/lib/private/sops/age
sudo age-keygen -o /var/lib/private/sops/age/keys.txt
sudo age-keygen -y /var/lib/private/sops/age/keys.txt  # Display public key
```

Edit secrets:

```bash
sops secrets/secrets.yaml              # Edit main secrets file
sops secrets/{hostname}.yaml           # Edit host-specific secrets
```

After adding recipients to `.sops.yaml`, rekey all secrets:

```bash
sops updatekeys secrets/secrets.yaml
```

**Never commit unencrypted secrets.** All sensitive data must be in encrypted `.yaml` files in `secrets/` directory.

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

Create package directory in `pkgs/`:

```bash
mkdir pkgs/my-package
```

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

Create host directory:

```bash
mkdir nixos/mynewhost      # or darwin/mynewhost
```

Create `nixos/mynewhost/default.nix`:

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

Create disk layout with Disko in `nixos/mynewhost/disks.nix`.

Build configuration:

```bash
nix build .#nixosConfigurations.mynewhost.config.system.build.toplevel
```

## Remote installation

Install NixOS to remote host using nixos-anywhere:

```bash
install-anywhere -h mynewhost -r <ip-address>
```

This script:

1. Uses Disko to partition and format disks
2. Installs NixOS configuration via `nixos-anywhere`
3. Reboots automatically when complete

After reboot, deploy Home Manager:

```bash
ssh mynewhost
sudo chown -Rv "$USER":users "$HOME/.config"
git clone https://github.com/wimpysworld/nix-config "$HOME/Zero/nix-config"
cd "$HOME/Zero/nix-config"
home-manager switch -b backup --flake .
```

## CI/CD workflows

GitHub Actions build configurations on flake.lock updates:

- **build-workstations.yml**: Desktop systems (vader, phasma)
- **build-laptops.yml**: Laptop systems (sidious, tanis, shaa, bane, atrius)
- **build-servers.yml**: Server systems (malak, maul, revan)
- **build-vms.yml**: Virtual machines (crawler, dagger)
- **build-macbook.yml**: Darwin systems (krall)
- **build-iso.yml**: ISO images
- **build-packages.yml**: Custom packages

Workflows use Determinate Systems actions for caching and optimisation.

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

**State version:**

StateVersion locked at `25.11`. Never change on existing systems (breaks compatibility). Only set on new installations.
