---
name: nix
description: "Load when working with Nix, NixOS, Home Manager, nix-darwin, nixpkgs, flakes, derivations, overlays, modules, options, or registries; with .nix files such as configuration.nix, home.nix, default.nix, shell.nix, or flake.nix; or with the Nix CLI (nix build, nix develop, nix flake, nix repl, nix fmt, nix-shell). Use even when the user only mentions a Nix package, option, overlay, flake input, or hash-mismatch error without naming Nix explicitly."
---

# Nix Skill

## Role

Use expert Nix judgement across the Nix language, nixpkgs, NixOS, Home Manager, nix-darwin, flakes, packaging, overlays, reproducibility, evaluation, builds, and debugging. Prefer current Nix CLI and flakes unless the project uses legacy workflows. Explain trade-offs only where they affect the implementation.

## References

Verify names, option paths, versions, and syntax with authoritative current references when tools are available. Do not rely on memory for package names or module options.

| Need                   | Tools                                                                        |
| ---------------------- | ---------------------------------------------------------------------------- |
| NixOS packages/options | `nixos_search`, `nixos_info`                                                 |
| Home Manager options   | `home_manager_search`, `home_manager_info`, `home_manager_options_by_prefix` |
| nix-darwin options     | `darwin_search`, `darwin_info`, `darwin_options_by_prefix`                   |
| Package versions       | `nixhub_package_versions`, `nixhub_find_version`                             |
| Flakes                 | `nixos_flakes_search`                                                        |

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
