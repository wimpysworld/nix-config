# Kuna CLI Reference

Adapted from `Noelo-Lab/kuna` (`skills/kuna/SKILL.md`, Apache-2.0) for Nix-installed `kuna` on `PATH`.

## Contents

- [Choose scope and decompile](#choose-scope-and-decompile)
- [Navigate a project export](#navigate-a-project-export)
- [Embedded documentation and option tuning](#embedded-documentation-and-option-tuning)
- [Search strings, crypto, blobs, and xrefs](#search-strings-crypto-blobs-and-xrefs)
- [Recover from packed or headerless inputs](#recover-from-packed-or-headerless-inputs)
- [Delegate bounded binary slices](#delegate-bounded-binary-slices)

## Choose scope and decompile

Kuna is a standalone CLI with no server and no persisted state between invocations. Export once for the chosen scope, then search the generated files with `rg`, file reads, and byte offsets.

Default to a streaming project export for multi-function binaries:

```bash
kuna decompile-project ./target --stream --jobs auto -o ./target.kuna
```

With `--stream`, completed functions become readable while the export continues. The scheduler prioritises the entry point, `main`, and their callees, though parallel workers can interleave other functions. Use `--jobs 1` for small binaries (roughly under 1 MB) or when callee-first prototype propagation matters more than wall-clock speed.

When image scale or runtime is unknown, run:

```bash
kuna functions ./target --summary --json
```

This reports function counts, entry point, reachability, and code bytes. Its `summary.runtime` array identifies PyInstaller, Nuitka, .NET, UPX, AutoIt, VB6, or twinBASIC bundles and names the right tool to use instead. Skip this extra call when scope is already clear.

For a few dozen short functions, `kuna decompile-all ./target` is readable directly. To narrow a project export, pass `--functions name1,name2` or repeatable `--addr 0x401000`. Note that `--filter REGEX` and `--reachable-from main` work on `functions` and `decompile-all`, not `decompile-project`.

Use `decompile` for one immediate function, a retry, or an option comparison:

```bash
kuna decompile ./target main
kuna decompile ./target 0x401230 --addr --json
```

Batch multiple functions with `decompile-all --json` instead of looping over `decompile`. Add `--omit aliases,line_mappings,variables,types` to keep JSON compact when only C output is needed.

## Navigate a project export

| Artifact | Purpose |
| --- | --- |
| `index.jsonl` | Streaming index with `name`, `addr`, `size`, `error`, and byte spans (`c_offset`, `c_len`). Search this first. |
| `<name>.c` | Decompiled function bodies under `// Function: <name> @ <addr>` headers. |
| `<name>.h` | Prototypes and recompile prelude. Recovered type definitions arrive at finalisation. |
| `<name>.asm` | Disassembly and data bytes. Search by symbol or address rather than reading whole files. |
| `README.md` | Image summary, progress, and success or failure counts. |
| `.streaming` | Live export status and operational failures while an export runs. |

Read only newline-terminated records in `index.jsonl`, because each complete line announces a finished C block. Streamed C follows completion order, so locate functions through `index.jsonl` rather than file order.

Inspect per-function errors even after a clean exit. Retry failed functions individually and raise `--max-fn-seconds` for timeouts. Store notes and helper scripts outside the export directory so a new export cannot overwrite them.

## Embedded documentation and option tuning

Run `kuna docs` to list embedded topics and sizes, then read only the needed topic:

- `kuna docs cli` for syntax, flags, exit codes, and JSON schemas.
- `kuna docs modes` for presets and size thresholds.
- `kuna docs options` and `kuna catalog --json` when tuning decompiler options.
- `kuna docs phases` only when pass-level context is needed.

Do not load `kuna docs --all` for routine work. Tune `--option NAME VALUE` only when a concrete discrepancy blocks analysis:

1. Confirm the discrepancy against assembly (`kuna disassemble`) or raw bytes (`kuna read`).
2. Search `kuna docs options` by symptom.
3. Change one option on the affected function, compare against evidence, and stop once resolved.

Supply known prototypes or types with `--assert` (or `@file`), and force function entries with `--define-function 0xADDR`. Using `--assert` requires serial decompilation without `--stream` (`--jobs 1`).

## Search strings, crypto, blobs, and xrefs

```bash
kuna strings ./target --filter '(?i)token|secret|error' --json
kuna crypto ./target --json          # AES, SHA, MD5, CRC, TEA, Base64 constants and callers
kuna blobs ./target --json           # Embedded PNG, JPEG, zip, gzip, xz, zstd (--extract DIR)
kuna xrefs ./target --from main --json
kuna disassemble ./target 0x401230 --addr
kuna read ./target 0x404000 --len 64
```

Verify critical branches, integer widths, signedness, and indirect calls against `kuna disassemble` and `kuna read` before drawing conclusions.

## Recover from packed or headerless inputs

| Input or failure | Action |
| --- | --- |
| UPX or NEOLite packed binary | Run `kuna unpack ./target -o ./target.unpacked`, then analyse the unpacked file. |
| Entry section lacks execute flag | Unpack first if packed, or retry with `--define-function 0xADDR` when the bytes are code. |
| Headerless raw image (for example DOS `.COM` or bare-metal firmware) | Pass `--raw-image --target <spec> --base <addr> --entry <addr> --jobs 1`. |
| Archive (`.zip`, `.tgz`) | Extract the archive and analyse the inner binary. |

Example for a 16-bit DOS `.COM` image loaded at `0x100`:

```bash
kuna decompile-all ./prog.com --raw-image \
  --target 'x86:LE:16:Real Mode' --base 0x100 --entry 0x100 --jobs 1
```

Raw-image mode requires explicit entry addresses and `--jobs 1`. Subcommands that rely on object metadata (`--summary`, `--reachable-from`, `strings`, `xrefs`, `disassemble`, `read`) do not apply to raw images; use REA with `--provider ghidra` when richer raw-binary or firmware inspection is needed.

## Delegate bounded binary slices

When delegating sub-tasks on a large binary, pass the binary path, the shared export directory, one bounded question, and the target symbols or addresses. Reuse the shared export directory instead of running duplicate `decompile-project` jobs.
