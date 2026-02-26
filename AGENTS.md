# AGENTS.md

## Project overview

NixOS, nix-darwin, and Home Manager flake managing multiple systems declaratively. Mixin pattern for composable modules. Builds workstations, servers, VMs, macOS systems, and ISO images.

## Commands

```bash
just host                           # Build and switch NixOS/nix-darwin
just home                           # Build and switch Home Manager
just switch                         # Switch both (home first, then host)
just apply                          # Apply both from FlakeHub Cache
just apply-home                     # Apply Home Manager from cache
just apply-host                     # Apply NixOS/nix-darwin from cache
just build                          # Build both (no switch)
just build-host                     # Build NixOS/nix-darwin only
just build-home                     # Build Home Manager only
just build-pkg firefox [vader]      # Build package [for specific host]
just check                          # nix flake check --show-trace
just eval                           # Evaluate flake syntax and all configs
just format [*paths]                # Format and lint Nix (deadnix, statix, nixfmt)
just lint-registry                  # Validate TOML registries against JSON schemas
just iso                            # Build nihilus ISO image
just update                         # Update flake.lock
just gc                             # Clean old generations, keep latest 5
just boot-host                      # Activate NixOS config on next reboot
just needs-reboot                   # Check if NixOS needs a reboot
just install vader 192.168.1.10     # Remote install via nixos-anywhere
just inject-tokens 192.168.1.10     # Inject age keys to ISO host
```

`just install` handles SOPS age key injection, SSH host key decryption, and LUKS setup. Optional: `keep_disks="true"`, `vm_test="true"`. `just inject-tokens` optional: `user="nixos"`.

## Code style

- British English spelling; comments use full sentences with proper punctuation
- `nixfmt` formatter (run via `nix fmt`)
- Prefer `lib.mkDefault`/`lib.mkForce` over plain values for overridability
- `lib.optional`/`lib.optionals` for conditional imports
- Explicit `inherit` statements for clarity
- String interpolation: `"${variable}"` not `variable`
- camelCase for Nix attributes and functions, kebab-case for files and directories
- Hostnames: Sith Lords (workstations/servers), TIE fighters (VMs)

## File structure

- `common/default.nix` - shared cross-platform config, imported by NixOS and nix-darwin
- `_mixins/` directories - self-contained modules, each with `default.nix` entry point
- `nixos/{hostname}/`, `darwin/{hostname}/` - host-specific configs (disks, kernel modules)
- `pkgs/` - custom packages, exposed via overlay; register in `pkgs/default.nix`
- `nixos/_mixins/scripts/`, `home-manager/_mixins/scripts/` - shell scripts
- `home-manager/_mixins/scripts/_template/` - script template

**Shell scripts** use `pkgs.writeShellApplication` (never `writeShellScriptBin`). Each script lives in its own directory: `script-name/default.nix` + `script-name.sh`. Runtime dependencies go in `runtimeInputs`. Shellcheck validation is automatic.

**Mixin placement:** system-level (services, kernel, boot, networking) in `nixos/_mixins/`; user-level (programs, dotfiles, scripts) in `home-manager/_mixins/`. Use `home.packages` in Home Manager, `environment.systemPackages` in NixOS.

## System registry

All systems defined in `lib/registry-systems.toml`, users in `lib/registry-users.toml` (read via `builtins.fromTOML`). Schemas in `lib/registry-systems-schema.json` and `lib/registry-users-schema.json`.

Registry fields:

- **kind** (required): `"computer"`, `"server"`, `"vm"`, `"container"`
- **platform** (required): `"x86_64-linux"`, `"aarch64-darwin"`, etc.
- **formFactor** (optional): `"laptop"`, `"desktop"`, `"handheld"`, `"tablet"`, `"phone"`
- **desktop** (optional): derived from kind + platform (Linux computer defaults to `"hyprland"`, Darwin to `"aqua"`)
- **username** (optional): defaults to `"martin"`
- **gpu** (optional): `vendors = ["amd", "nvidia"]`, optional `compute` block with `vendor`, `vram`, `unified`
- **displays** (optional): list with output, width, height, refresh, scale, position, primary, workspaces
- **tags** (optional): `["studio", "thinkpad", "iso"]`
- **keyboard** (optional): `layout` (defaults to `"gb"`), `variant`

ISO hosts use `tags = ["iso"]` which implies `desktop = null`, `username = "nixos"`. The ISO host is `nihilus`.

`resolveEntry` in `lib/flake-builders.nix` merges four layers: baseline username, kind+OS derived desktop, ISO defaults, then explicit values. The registry entry flows through `resolveEntry` -> `mkSystemConfig` -> `mkNixos`/`mkHome`/`mkDarwin` -> `noughty.*` options. No other files need updating when adding a host.

## Noughty module system

All host/user metadata accessed via `config.noughty.*`, not `specialArgs`. Provides type checking, defaults, and `mkDefault`/`mkForce` overridability.

Only four `specialArgs`: `inputs`, `outputs`, `stateVersion`, `catppuccinPalette`.

Module shorthand: use `inherit (config.noughty) host;` in `let` bindings (not `cfg`).

```nix
{ config, noughtyLib, lib, ... }:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.workstation {
  # host.name, host.desktop, host.is.laptop, host.gpu.hasNvidia, etc.
}
```

Key gating patterns:

- `host.is.workstation`, `host.is.server`, `host.is.laptop`, `host.is.iso`, `host.is.vm`, `host.is.darwin`, `host.is.linux`
- `host.gpu.hasNvidia`, `host.gpu.hasCuda`, `host.gpu.hasAmd`, `host.gpu.hasROCm`
- `host.display.primaryOutput`, `host.display.isMultiMonitor`
- `noughtyLib.isUser [ "martin" ]`, `noughtyLib.isHost [ "vader" "phasma" ]`
- `noughtyLib.hostHasTag "studio"`, `noughtyLib.userHasTag "developer"`

Full reference: `lib/noughty/README.md`.

## Module gating patterns

**Flat pattern** (~95% of modules): `lib.mkIf condition { ... }` as the entire module body.

**Long-form pattern** (hub modules with `imports`):

```nix
{ imports = [...]; config = lib.mkIf condition { ... }; }
```

Imports stay unconditional; each sub-module gates itself. Never use `lib.optional config.noughty.* ./foo` in `imports` - causes infinite recursion.

## Secrets management

Secrets encrypted with sops-nix using age keys.

- **User key:** `~/.config/sops/age/keys.txt`
- **Host key:** `/var/lib/private/sops/age/keys.txt`
- **Edit:** `sops secrets/secrets.yaml` or `sops secrets/host-{hostname}.yaml`
- **Rekey:** `sops updatekeys secrets/secrets.yaml`

`just inject-tokens` sends age keys to `/tmp/injected-tokens/` on ISO media. Both keys are hard requirements for `install-system`.

## Catppuccin theming

Catppuccin Mocha palette via `catppuccinPalette` (passed in `specialArgs`):

- `getColor "base"` - hex with `#`
- `getHyprlandColor "blue"` - hex without `#`
- `colors` - raw palette attribute set
- `isDark` - true for mocha
- `preferShade` - `"prefer-dark"` for dark themes

## Overlays

Three overlays applied in order:

- `localPackages` - custom packages from `pkgs/`
- `modifiedPackages` - overrides and patches to nixpkgs
- `unstablePackages` - nixpkgs-unstable via `pkgs.unstable`

## CI/CD

Four workflows in `.github/workflows/`:

- **`builder.yml`** - PRs and pushes to main: inventory via `flake-inventory.sh`, parallel per-host/per-package builds, publish to FlakeHub Cache, ISO release on main
- **`freshener.yml`** - scheduled auto-updates for proprietary packages (Wavebox, Defold) via PR
- **`updater.yml`** - scheduled `flake.lock` updates via PR
- **`checker.yml`** - scheduled flake lock health checks and TOML registry schema validation

Auto-merge of update PRs gated on all build jobs passing.

## Troubleshooting

- **Infinite recursion** - `config.noughty.*` used inside `imports`; move to `config` block
- **Home Manager activation fails** - file conflicts; use `home-manager switch -b backup --flake .`
- **Secrets not accessible** - verify age keys exist; check `.sops.yaml` recipients; run `sops updatekeys`
- **Package not found** - verify in `pkgs/default.nix` and overlay applied; `nix search nixpkgs <name>`
- **Shellcheck failure** - use `writeShellApplication` (not `writeShellScriptBin`); add deps to `runtimeInputs`

## Constraints

- Never modify `flake.lock` directly; use `just update`
- Never change `stateVersion` on existing systems
- Never commit unencrypted secrets outside `secrets/`
- Never use `environment.systemPackages` in Home Manager; use `home.packages`
- Never use `writeShellScriptBin`; use `writeShellApplication`
- Never use `config.noughty.*` inside `imports`; use the long-form `config = lib.mkIf` pattern
- Run `just eval` before committing to catch evaluation errors
- Keep each mixin self-contained with a single concern
