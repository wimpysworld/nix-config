# flake-build

Platform-aware build script for Nix flake outputs. Discovers and builds all outputs for the current system without evaluating foreign-platform configurations.

## Why this exists

CI workflows need to build every flake output (NixOS, Darwin, Home Manager, packages, dev shells, formatter) and cache them in FlakeHub Cache. Previously, `DeterminateSystems/flake-iter` handled discovery, but it has a fundamental design flaw: it evaluates **all** flake outputs across **all** platforms before filtering by system. The filtering happens in Rust after Nix evaluation completes.

This means a macOS runner evaluates every `nixosConfigurations` entry (Linux-only), and a Linux runner evaluates every `darwinConfigurations` entry (macOS-only). If any foreign-platform configuration references a broken package, the entire evaluation fails, and the runner cannot discover even its own outputs. There is no CLI flag, environment variable, or workaround.

This caused real CI failures when upstream nixpkgs marked the `bcachefs` kernel module as broken - the macOS runner couldn't build anything because evaluating the Linux NixOS configurations failed first.

`flake-build` solves this by only evaluating outputs relevant to the current platform.

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

Called from `.github/workflows/ci.yml` in the build matrix job:

```yaml
- name: Build 🏗️
  env:
    FLAKE_BUILD_SYSTEM: ${{ matrix.systems.nix-system }}
  run: |
    bash home-manager/_mixins/scripts/flake-build/flake-build.sh
```

The inventory job still uses `flake-iter` to enumerate runner/system pairs for the matrix. `flake-build` replaces only the build step.

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
