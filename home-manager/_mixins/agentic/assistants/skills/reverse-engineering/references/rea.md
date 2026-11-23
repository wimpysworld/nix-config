# REA Provider and Environment Reference

Local reference for Reverse Engineer Anything (`rea`) as configured on Linux developer workstations in this Nix setup.

## Contents

- [Provider selection: Kuna default vs Ghidra fallback](#provider-selection-kuna-default-vs-ghidra-fallback)
- [Operations that require Ghidra](#operations-that-require-ghidra)
- [Built-in non-native analysers](#built-in-non-native-analysers)
- [MCP vs CLI lifecycle](#mcp-vs-cli-lifecycle)
- [Fence and local environment paths](#fence-and-local-environment-paths)

## Provider selection: Kuna default vs Ghidra fallback

The Nix wrapper for `rea` and `rea-agents` sets these defaults:

- `REA_ANALYSIS_PROVIDER=kuna`
- `REA_KUNA_COMMAND=<nix-store>/bin/kuna` (prebuilt Kuna `1.1000`, verified by REA `6.10.1`)
- `GHIDRA_INSTALL_DIR=<nix-store>/lib/ghidra` (Ghidra `12.2`)
- `JAVA_HOME=<nix-store>/lib/openjdk` (JDK `25`)

Because `REA_ANALYSIS_PROVIDER=kuna` is a standing preference, REA selects Kuna automatically on native targets and does not fall back to Ghidra on unsupported formats. Select Ghidra explicitly when needed:

- **CLI:** pass `--provider ghidra` (or set `REA_ANALYSIS_PROVIDER=ghidra` for one command).
- **MCP:** pass `"provider_id": "ghidra"` in `open_binary`.

| Capability | Kuna (`default`) | Ghidra (`--provider ghidra`) |
| --- | --- | --- |
| Startup and speed | Fast native Rust binary (no JVM) | Slow cold start (JVM + full auto-analysis) |
| Formats | ELF, thin Mach-O only | ELF, Windows PE, fat/thin Mach-O, raw binary, GameCube DOL, PSP, 16-bit DOS (MZ/COM) |
| Architectures | x86-64, AArch64, ARM only | x86/x64, ARM/AArch64, MIPS, PowerPC, RISC-V, 16-bit x86, and more |
| REA operations | 13 core read-only operations | 30 operations (bytes, layout, types, indirect calls, annotations) |

## Operations that require Ghidra

Kuna covers `list_documents`, `list_procedures`, `search_procedures`, `procedure_address`, `address_name`, `procedure_pseudo_code`, `procedure_assembly`, `procedure_callers`, `procedure_callees`, `list_strings`, `search_strings`, `xrefs`, and `analyze_function`.

Switch to Ghidra when the investigation requires any of these 17 operations:

- **Raw bytes and image layout:** `read_bytes`, `search_bytes`, `list_segments`, `address_to_file_offset`, `inspect_native_load_image`, `read_binary_inventory_summary`, `list_names`.
- **Deep instruction, type, and reference inspection:** `procedure_info`, `procedure_references`, `read_function_instructions`, `resolve_containing_procedure`, `inspect_native_instruction`, `inspect_native_data_type`, `resolve_native_call_targets`.
- **Iterative annotation:** `set_address_name`, `set_addresses_names`, `annotate_native_function`.

## Built-in non-native analysers

These REA workflows need neither Kuna nor Ghidra and work identically via `rea` CLI or MCP:

- JavaScript and Electron applications (`analyze-javascript-application`, `audit-release-exposure`, ASAR extraction, preload/IPC tracing).
- .NET / PE CLI metadata and CIL inspection (static, never executes target code).
- Embedded Go module/build metadata and `cargo-auditable` Rust dependency metadata.
- PyInstaller archives, Deno standalone binaries, Godot PCK archives, Unity IL2CPP `global-metadata.dat`, Erlang BEAM, and NuGet packages.
- ELF dependencies/notes/kernel modules, PE imports/Authenticode certificates, binary hardening flags, DWARF compile units, and SQLite snapshots.

## MCP vs CLI lifecycle

- **REA MCP (`<harness>-fenced-rea`):** Launches `agy-fenced-rea`, `claude-fenced-rea`, `codex-fenced-rea`, `opencode-fenced-rea`, or `pi-fenced-rea` with `rea --mcp` enabled for that session only. Use this for multi-function native work: the session retains the Evidence ledger in memory and keeps Kuna's background `decompile-project` export running to completion so later queries upgrade from single-function output to whole-program prototypes.
- **One-shot `rea` CLI:** Exiting a CLI command cancels any background Kuna project export. Use one-shot CLI for built-in non-native analysers, single queries, or scripted checks, and use bare `kuna decompile-project` when you want a persistent on-disk export without MCP.
- **Excluded clients:** `rea --mcp` is deliberately omitted from normal `<harness>-fenced` sessions, LibreChat, Zed, and Moltis.

## Fence and local environment paths

- Pre-wired companion tools in the `rea` wrapper: `tshark` and `capinfos` (`4.x`), `util-linux` `prlimit`, `binwalk` (`3.1.0`), `unblob` (`26.6.4`), `objdump`, `gdb`, `rizin`, `mitmdump` (`12.2.3`), `apktool`, `adb`, `jadx-headless-mcp` (`0.7.1`), `wabt` (`1.0.42`), and `sigrok-cli` (`0.7.2`).
- Writable Fence paths for REA and Android: `~/.android`, `~/.rea`, `~/.config/rea`, `~/.config/ghidra`, and `~/.cache/rea/kuna` (covered by `~/.cache`).
- Hardware device nodes exposed in Fence on REA-enabled Linux hosts: `/dev/bus/usb` and `/dev/hidraw0` through `/dev/hidraw31` (gated by host kernel and udev permissions).
- Kuna project cache cap defaults to 4 GiB (`REA_KUNA_CACHE_MAX_BYTES`).
- Kuna defaults to `REA_KUNA_JOBS=1` inside REA so callee-first prototype propagation stays deterministic.
- Never run `rea setup`, never invoke `npx rea-agents`, and never attempt Hopper setup on NixOS.
