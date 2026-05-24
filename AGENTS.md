# AGENTS.md

## Scope

This repository is a NixOS, nix-darwin, and Home Manager flake for workstations, servers, VMs, macOS systems, and ISO images.

`AGENTS.md` is the canonical agent instruction file. `CLAUDE.md` only imports it; keep vendor-specific shims thin and do not duplicate rules there.

Preserve runnable commands, Nix module patterns, registry semantics, and tool-specific configuration. Never delete files without explicit confirmation.

## Reference tools

Use the NixOS MCP server as the primary reference for NixOS, Home Manager, nix-darwin options, packages, modules, versions, and flakes. Do not rely on training data when an MCP lookup can answer the question.

| Purpose                | Tools                                                                                                                    |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| NixOS options/packages | `mcp__nixos__nixos_search`, `mcp__nixos__nixos_info`                                                                     |
| Home Manager options   | `mcp__nixos__home_manager_search`, `mcp__nixos__home_manager_options_by_prefix`, `mcp__nixos__home_manager_list_options` |
| nix-darwin options     | `mcp__nixos__darwin_search`, `mcp__nixos__darwin_options_by_prefix`, `mcp__nixos__darwin_list_options`                   |
| Package versions       | `mcp__nixos__nixhub_package_versions`, `mcp__nixos__nixhub_find_version`                                                 |
| Flake search           | `mcp__nixos__nixos_flakes_search`                                                                                        |

## Commands

Run `just --list --unsorted` before inventing commands.

| Task                          | Command                                                                                                                                  |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Format and lint Nix files     | `just format [paths]` or `nix fmt`                                                                                                       |
| Validate registries           | `just lint-registry`                                                                                                                     |
| Evaluate flake and configs    | `just eval`                                                                                                                              |
| Run flake checks              | `just check`                                                                                                                             |
| Build all configs             | `just build`                                                                                                                             |
| Build one host or Home config | `just build-host hostname=<host>`; `just build-home username=<user> hostname=<host>`                                                     |
| Build a package               | `just build-pkg pkg=<pkg> hostname=<host>`                                                                                               |
| Switch or apply configs       | `just switch`; `just apply`; `just apply-home`; `just apply-host`                                                                        |
| Update flake inputs           | `just update`                                                                                                                            |
| ISO and install               | `just iso`; `just inject-tokens remote=<host> user=nixos`; `just install host=<host> remote=<target> keep_disks="false" vm_test="false"` |

Run `just eval` before finishing Nix changes. Run `just lint-registry` after editing registry TOML.

## Layout

- `common/default.nix` - shared cross-platform config imported by NixOS and nix-darwin.
- `nixos/{hostname}/`, `darwin/{hostname}/` - host-specific configs, disks, kernel modules.
- `_mixins/` directories - self-contained modules with a `default.nix` entry point.
- `nixos/_mixins/` - system-level services, kernel, boot, networking, system packages.
- `home-manager/_mixins/` - user programs, dotfiles, user scripts, Home packages.
- `pkgs/` - custom packages exposed through the local overlay; register new packages in `pkgs/default.nix`.
- `.github/workflows/` - CI behaviour and auto-merge gates.

Use `home.packages` in Home Manager and `environment.systemPackages` in NixOS.

## Registries and noughty

All systems live in `lib/registry-systems.toml`; users live in `lib/registry-users.toml`. Schemas are `lib/registry-systems-schema.json` and `lib/registry-users-schema.json`.

System entries require `kind` and `platform`. Common fields include `formFactor`, `desktop`, `username`, `tags`, `gpu`, `displays`, `keyboard`, and `network.wifi`.

ISO hosts use `tags = ["iso"]`, which implies `desktop = null` and `username = "nixos"`. The ISO host is `nihilus`.

`resolveEntry` in `lib/flake-builders.nix` merges four layers, in order: baseline username, kind+OS derived desktop, ISO defaults, then explicit registry values. Registry data flows through `resolveEntry` -> `mkSystemConfig` -> `mkNixos`/`mkHome`/`mkDarwin` -> `config.noughty.*`.

Read host and user metadata from `config.noughty.*`, not from `specialArgs`. Noughty provides type checking, defaults, and `mkDefault`/`mkForce` overridability.

Only four `specialArgs` are expected: `inputs`, `outputs`, `stateVersion`, `catppuccinPalette`. Full reference: `lib/noughty/README.md`.

Key gates:

- `host.is.workstation`, `host.is.server`, `host.is.laptop`, `host.is.iso`, `host.is.vm`, `host.is.darwin`, `host.is.linux`
- `host.gpu.hasNvidia`, `host.gpu.hasCuda`, `host.gpu.hasAmd`, `host.gpu.hasROCm`
- `host.display.primaryOutput`, `host.display.isMultiMonitor`
- `noughtyLib.isUser [ "martin" ]`, `noughtyLib.isHost [ "skrye" "zannah" ]`, `noughtyLib.hostHasTag "studio"`, `noughtyLib.userHasTag "developer"`

## Module gating patterns

Use the flat pattern for most modules:

```nix
lib.mkIf condition { ... }
```

Use the long-form pattern for hub modules with imports:

```nix
{
  imports = [ ... ];
  config = lib.mkIf condition { ... };
}
```

Keep imports unconditional; each sub-module gates itself. Never use `lib.optional config.noughty.* ./foo` in `imports`, because it causes infinite recursion.

## Nix style

- British English spelling; comments use full sentences with proper punctuation.
- Format with `nixfmt` via `nix fmt` or `just format`.
- Prefer `lib.mkDefault` and `lib.mkForce` over plain values for overridability.
- Use `lib.optional` and `lib.optionals` for conditional lists.
- Use explicit `inherit` statements for clarity.
- Use string interpolation inside strings: `"${variable}"`.
- Use camelCase for Nix attributes and functions; kebab-case for files and directories.
- Hostnames follow themes: Sith Lords for workstations/servers, TIE fighters for VMs.

## Scripts, packages, and secrets

Shell scripts use `pkgs.writeShellApplication`, never `writeShellScriptBin`. Each script lives in its own directory with `default.nix` and `script-name.sh`. Put runtime tools in `runtimeInputs`; shellcheck runs automatically. Use `home-manager/_mixins/scripts/_template/` for new script modules.

Custom packages belong under `pkgs/<name>/default.nix` and must be registered in `pkgs/default.nix`.

Secrets are encrypted with sops-nix using age keys: user key `~/.config/sops/age/keys.txt`; host key `/var/lib/private/sops/age/keys.txt`. Edit with `sops secrets/secrets.yaml` or `sops secrets/host-<hostname>.yaml`; rekey with `sops updatekeys secrets/secrets.yaml`.

`just inject-tokens` sends age keys to `/tmp/injected-tokens/` on ISO media. Both user and host keys are required for `install-system`.

## Catppuccin, overlays, and CI

Catppuccin Mocha is available through `catppuccinPalette`: `getColor "base"` includes `#`; `getHyprlandColor "blue"` omits `#`; `colors` is the raw palette; `isDark = true`; `preferShade = "prefer-dark"`.

Overlays apply in this order: `localPackages`, `modifiedPackages`, `unstablePackages`.

Read `.github/workflows/` before changing CI assumptions. Auto-merge of update PRs requires every build job to pass.

## Troubleshooting

| Symptom                               | Fix                                                                                    |
| ------------------------------------- | -------------------------------------------------------------------------------------- |
| Infinite recursion                    | Move `config.noughty.*` out of `imports`; use long-form `config = lib.mkIf`.           |
| Home Manager activation file conflict | Run `home-manager switch -b backup --flake .`.                                         |
| Secrets unavailable                   | Verify both age keys, check `.sops.yaml` recipients, run `sops updatekeys`.            |
| Package not found                     | Confirm registration in `pkgs/default.nix`, then check the name with NixOS MCP search. |
| Shellcheck failure                    | Use `writeShellApplication` and add missing tools to `runtimeInputs`.                  |

## Constraints

- Never edit `flake.lock` directly; use `just update`.
- Never change `stateVersion` on existing systems.
- Never commit unencrypted secrets outside `secrets/`.
- Never use `environment.systemPackages` in Home Manager; use `home.packages`.
- Never use `writeShellScriptBin`; use `writeShellApplication`.
- Never use `config.noughty.*` inside `imports`; use long-form `config = lib.mkIf`.
- Keep each mixin self-contained with a single concern.
