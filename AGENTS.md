# AGENTS.md

## Project overview

NixOS, nix-darwin, and Home Manager flake managing multiple systems declaratively. Mixin pattern for composable modules. Builds workstations, servers, VMs, macOS systems, and ISO images.

## Discovery tools

A NixOS MCP server is available and must be used as the primary reference for NixOS, Home Manager, and nix-darwin options, packages, and modules - do not rely on training data for these.

| Purpose | Tools |
|---------|-------|
| NixOS options/packages | `mcp__nixos__nixos_search`, `mcp__nixos__nixos_info` |
| Home Manager options | `mcp__nixos__home_manager_search`, `mcp__nixos__home_manager_options_by_prefix`, `mcp__nixos__home_manager_list_options` |
| nix-darwin options | `mcp__nixos__darwin_search`, `mcp__nixos__darwin_options_by_prefix`, `mcp__nixos__darwin_list_options` |
| Package versions | `mcp__nixos__nixhub_package_versions`, `mcp__nixos__nixhub_find_version` |
| Flake search | `mcp__nixos__nixos_flakes_search` |

## Commands

Run `just --list` to see all available recipes with descriptions.

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

All systems defined in `lib/registry-systems.toml`, users in `lib/registry-users.toml` (read via `builtins.fromTOML`). Full field reference: `lib/registry-systems-schema.json` and `lib/registry-users-schema.json`.

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

Four workflows in `.github/workflows/` - read them to understand CI behaviour. Auto-merge of update PRs is gated on all build jobs passing.

## Troubleshooting

- **Infinite recursion** - `config.noughty.*` used inside `imports`; move to `config` block
- **Home Manager activation fails** - file conflicts; use `home-manager switch -b backup --flake .`
- **Secrets not accessible** - verify age keys exist; check `.sops.yaml` recipients; run `sops updatekeys`
- **Package not found** - verify in `pkgs/default.nix` and overlay applied; use `mcp__nixos__nixos_search` to confirm package name
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
