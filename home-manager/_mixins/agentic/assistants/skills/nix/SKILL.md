
# Nix Skill

## Role

Use expert Nix judgement across the Nix language, nixpkgs, NixOS, Home Manager, nix-darwin, flakes, packaging, overlays, reproducibility, evaluation, builds, and debugging. Prefer current Nix CLI and flakes unless the project uses legacy workflows. Explain trade-offs only where they affect the implementation.

## References

Verify names, option paths, versions, and syntax with authoritative current references when tools are available. Do not rely on memory for package names or module options.

| Need                   | Tool and key parameters                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------------------------- |
| NixOS packages/options | `nix` (`action`: `search`/`info`, `source`: `nixos`, `type`: `packages`/`options`/`programs`)           |
| Home Manager options   | `nix` (`action`: `search`/`info`/`browse`, `source`: `home-manager`)                                    |
| nix-darwin options     | `nix` (`action`: `search`/`info`/`browse`, `source`: `darwin`)                                          |
| Flakes and inputs      | `nix` (`action`: `search`/`info`, `source`: `flakes`/`flakehub`, or `action`: `flake-inputs`)           |
| Cache, channels, store | `nix` (`action`: `cache`, `channels`, or `store` with `type`: `ls`/`read`)                              |
| Package versions       | `nix_versions` (`package`, optional `version`)                                                          |

## Guidance

- Model module changes through options, `lib.mkIf`, `lib.mkMerge`, priorities, and imports that match the existing project architecture.
- Use `home.packages` for Home Manager user packages and `environment.systemPackages` for NixOS system packages.
- Package with the appropriate nixpkgs builder: `stdenv.mkDerivation`, `buildGoModule`, `buildPythonPackage`, Rust builders, Node builders, or project-specific helpers.
- Prefer overlays and overrides for package customisation; keep local packages composable and easy to build with `nix build`.
- Treat hash mismatches as normal fixed-output derivation workflow: use a fake hash, build, copy the reported hash, then rebuild.
- Debug by separating parse errors, evaluation errors, option type errors, missing attributes, dependency failures, and runtime failures.
- Preserve reproducibility: pin inputs through flakes or project lock policy, avoid impurity unless the project already requires it.

## Commands

Prefer project commands for formatting, evaluation, checks, builds, and updates. Common fallbacks are `nix fmt`, `nix flake check`, `nix build`, `nix develop`, `nix eval`, and `nix repl`.

## Constraints

- Never edit lock files directly unless project policy explicitly says to do so; use the project update command or `nix flake update`.
- Never change existing NixOS or Home Manager state version values unless explicitly requested.
- Never assume packages, options, or flake outputs exist; verify them.
- Never use legacy `nix-build`, `nix-shell`, or `nix-env` when the project uses flakes and the new CLI.
- Preserve existing module architecture, naming conventions, formatting, and validation commands.
