# flake-build

Platform-aware build script for Nix flake outputs. Discovers and builds all outputs for the current system without evaluating foreign-platform configurations. Primarily used as a **local development tool** for verifying builds before committing.

## Why this exists

Building all flake outputs locally requires discovering which outputs belong to the current platform without evaluating foreign-platform configurations. Naively evaluating all outputs fails when any foreign-platform configuration references a broken package, because Nix evaluates everything before any filtering can occur.

`flake-build` solves this by only enumerating attribute names (via lazy `builtins.attrNames` evaluation) and building outputs relevant to the current platform.

In CI, output discovery and building are handled separately: `flake-inventory` discovers outputs and emits GitHub Actions matrices, and the workflow builds each output type in dedicated parallel jobs. See the [flake-inventory README](../flake-inventory/README.md) for the CI architecture.

## How it works

### 1. System detection

Reads `FLAKE_BUILD_SYSTEM` if set, otherwise runs `nix eval --impure --expr 'builtins.currentSystem'`. The system string (e.g. `x86_64-linux`, `aarch64-darwin`) determines which output categories to process.

### 2. Output discovery

Uses `nix eval .#<output> --apply builtins.attrNames --json` to enumerate attribute names per category. This completes in ~50ms because Nix's lazy evaluation only needs the attribute names, not full configuration evaluation.

**Linux** discovers: `nixosConfigurations`, `packages.<system>`, `devShells.<system>`, `formatter.<system>`

**macOS** discovers: `darwinConfigurations`, `packages.<system>`, `devShells.<system>`, `formatter.<system>`

**Both** discover: `homeConfigurations` (with platform filtering, see below)

### 3. homeConfigurations filtering

Home Manager attribute names use `user@hostname` format. The hostname is cross-referenced against already-discovered `nixosConfigurations` (Linux) or `darwinConfigurations` (macOS) names to determine platform ownership.

Orphan configs, where the hostname doesn't match any system configuration, have their platform evaluated individually:

```
nix eval .#homeConfigurations."<name>".pkgs.stdenv.hostPlatform.system
```

### 4. Building

Each output is built with `nix build --no-link -L`. Failures are tracked but don't halt execution - all remaining outputs continue building. A summary prints at the end, and the script exits non-zero if any build failed.

### 5. Package skip via `hydraPlatforms`

Packages that evaluate successfully but set `meta.hydraPlatforms = []` are skipped. This is the standard nixpkgs convention for packages that cannot be built in CI, such as `requireFile` packages that need manually-provided source files. The check only applies to packages, not devShells.

### Build attribute paths

| Output type | Attribute path |
|---|---|
| nixosConfigurations | `.#nixosConfigurations.<name>.config.system.build.toplevel` |
| darwinConfigurations | `.#darwinConfigurations.<name>.config.system.build.toplevel` |
| homeConfigurations | `.#homeConfigurations."<user>@<host>".activationPackage` |
| packages | `.#packages.<system>.<name>` |
| devShells | `.#devShells.<system>.<name>` |
| formatter | `.#formatter.<system>` |

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `FLAKE_BUILD_SYSTEM` | auto-detected | Nix system to build for (e.g. `x86_64-linux`, `aarch64-darwin`) |
| `FLAKE_BUILD_VERBOSE` | `0` | Set to `1` for detailed discovery output |
| `FLAKE_BUILD_DIR` | `.` | Path to the flake directory |

## Usage

### CI

`flake-build` is no longer used in CI. The workflow in `.github/workflows/ci.yml` now uses `flake-inventory` for output discovery and has inline build steps per job type (devshells, packages, nixos, darwin, orphan-homes). Each NixOS and Darwin configuration builds on its own runner via a matrix strategy, driven by the per-host matrices that `flake-inventory` emits. See the [flake-inventory README](../flake-inventory/README.md) for details.

### Local

Available as a wrapped command via the `default.nix` wrapper (using `writeShellApplication` with `jq` and `nix` as runtime inputs):

```bash
# Build all outputs for the current system
flake-build

# Build with verbose discovery output
FLAKE_BUILD_VERBOSE=1 flake-build

# Target a specific platform
FLAKE_BUILD_SYSTEM=aarch64-darwin flake-build
```

## Runtime dependencies

Declared in `default.nix` via `writeShellApplication`:

- `jq` - JSON parsing for attribute name arrays and hostname cross-referencing
- `nix` - evaluation and building
