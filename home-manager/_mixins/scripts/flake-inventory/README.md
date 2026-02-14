# flake-inventory

Discovery script for Nix flake outputs. Enumerates all buildable outputs and emits GitHub Actions matrix JSON that drives parallel downstream build jobs.

## Why this exists

CI workflows need to build every flake output in parallel across multiple platforms (`x86_64-linux`, `aarch64-darwin`). GitHub Actions requires a JSON matrix to spawn parallel jobs, but there was no tool to generate these matrices from flake outputs without triggering full evaluation.

Previously, `DeterminateSystems/flake-iter` handled discovery, but it has a fundamental design flaw: it evaluates **all** flake outputs across **all** platforms before filtering by system. The `--system` flag filters in Rust code **after** `nix eval` completes. If any foreign-platform configuration references a broken package, the entire evaluation fails, preventing discovery of even native outputs.

`flake-inventory` solves this by only enumerating attribute names via lazy evaluation (`builtins.attrNames`, ~50ms per category) and mapping them to the correct platform runners without ever deeply evaluating any configuration.

## Why per-host parallelism

NixOS and Darwin configurations are built **one per runner** (parallel matrix jobs) rather than sequentially on a single runner per platform. The primary constraint is disk capacity: GitHub Actions runners provide roughly 28-75GB of usable space (depending on runner type and `nothing-but-nix` reclamation), while a single NixOS configuration closure can consume 15-30GB. With 13+ NixOS configurations in this flake, sequential builds on one runner would require far more disk than any single runner can provide.

Per-host runners also allow FlakeHub Cache to push artefacts incrementally during each build, so parallel runners benefit from each other's cache pushes mid-flight. Wall-clock time drops from 90+ minutes (if sequential were even feasible) to roughly 20 minutes.

## How it works

### 1. DevShells and formatter discovery

For each platform in `PLATFORMS` (`x86_64-linux`, `aarch64-darwin`):

- Discovers devShell names via `nix eval .#devShells.<system> --apply builtins.attrNames --json`
- Checks whether a formatter exists for the platform
- Emits one matrix entry per platform with: `system`, `runner`, `shells` array, `formatter` boolean

### 2. Packages discovery

For each platform:

- Discovers package names via `nix eval .#packages.<system> --apply builtins.attrNames --json`
- Emits one matrix entry per platform with: `system`, `runner`, `packages` array

### 3. System configuration discovery

Enumerates `nixosConfigurations`, `darwinConfigurations`, and `homeConfigurations` attribute names. These are used for cross-referencing in the next phases.

### 4. NixOS matrix (per-host)

For each `nixosConfiguration`:

- Pairs it with a matching `homeConfiguration` by finding `user@hostname` entries where the hostname matches
- Emits one matrix entry per host with: `name`, `runner` (`ubuntu-latest`), `home` (paired homeConfiguration name or empty)

### 5. Darwin matrix (per-host)

Same as NixOS but for `darwinConfigurations`, using `macos-latest` runner.

### 6. Orphan homeConfigurations

Home configs whose hostname doesn't match any `nixosConfiguration` or `darwinConfiguration` (e.g. lima, wsl, gaming types that only have Home Manager configs). All assumed to be `x86_64-linux` in this flake.

- Emits one matrix entry per orphan with: `name`, `runner`

## Outputs emitted

Five JSON matrix arrays written to `$GITHUB_OUTPUT`:

| Output | Content |
|---|---|
| `devshells` | Per-platform devShell + formatter matrix |
| `packages` | Per-platform package matrix |
| `nixos` | Per-host NixOS matrix (with paired home configs) |
| `darwin` | Per-host Darwin matrix (with paired home configs) |
| `orphan_homes` | Orphan Home Manager configs |

Five boolean guards to prevent empty-matrix failures in downstream jobs:

`has_devshells`, `has_packages`, `has_nixos`, `has_darwin`, `has_orphan_homes`

## Runner mapping

| Nix system | GitHub Actions runner |
|---|---|
| `x86_64-linux` | `ubuntu-latest` |
| `aarch64-darwin` | `macos-latest` |

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `FLAKE_INVENTORY_DIR` | `.` | Path to the flake directory |
| `FLAKE_INVENTORY_VERBOSE` | `0` | Set to `1` for detailed discovery output |
| `GITHUB_OUTPUT` | `/dev/stdout` | GitHub Actions output file (auto-set in CI) |

## Usage

### CI

Called from `.github/workflows/ci.yml` in the inventory job:

```yaml
- name: Inventory
  id: inventory
  run: bash home-manager/_mixins/scripts/flake-inventory/flake-inventory.sh
```

Downstream jobs consume the outputs:

```yaml
nixos:
  needs: inventory
  if: needs.inventory.outputs.has_nixos == 'true'
  strategy:
    matrix:
      target: ${{ fromJSON(needs.inventory.outputs.nixos) }}
```

### Local

Available as a wrapped command via the `default.nix` wrapper (using `writeShellApplication` with `jq` and `nix` as runtime inputs):

```bash
# Discover all outputs (prints to stdout)
flake-inventory

# With verbose output
FLAKE_INVENTORY_VERBOSE=1 flake-inventory
```

## Runtime dependencies

Declared in `default.nix` via `writeShellApplication`:

- `jq` - JSON construction and querying for matrix assembly
- `nix` - lazy evaluation of flake attribute names
