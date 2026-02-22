# Heynote - Nix Source Build

Nix package for [Heynote](https://heynote.com/), a dedicated scratchpad for developers. Builds from source using `buildNpmPackage` and `electron-builder` on Linux and macOS, with Catppuccin colour themes applied at build time.

## Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| `x86_64-linux` | x86_64 | Builds and tested |
| `aarch64-linux` | ARM64 | Builds |
| `x86_64-darwin` | Intel Mac | Builds |
| `aarch64-darwin` | Apple Silicon | Builds |

Platform support matches `electron_39` availability in nixpkgs.

## Building

```bash
# Via justfile (recommended)
just build-pkg heynote

# Via nix build
nix build .#heynote

# Build for a specific host
just build-pkg heynote vader
```

The built application is available at `./result/bin/heynote`.

## Build Method

The package uses `buildNpmPackage` to fetch and vendor npm dependencies, then invokes `electron-builder` to produce a distributable Electron application. It builds from source at the `v2.8.2` tag of `heyman/heynote` using the nixpkgs `electron_39` package.

Key build steps:

1. `postPatch` - Rewrites dependency declarations and separates vite build from electron-builder
2. `preBuild` - Symlinks system ripgrep, applies Catppuccin theme patches, copies Electron dist, rebuilds native modules
3. `buildPhase` - Runs `npm run build` (Vite/Vue), then `npx electron-builder` with platform-specific flags
4. `installPhase` - Copies built output, links system ripgrep into the asar bundle, creates wrapper scripts

## Cross-Platform Architecture

The package uses platform-conditional logic throughout to produce correct output on both Linux and macOS.

### Platform Detection

A helper variable computes the electron-builder cache tag dynamically:

```nix
electronPlatformTag =
  if stdenv.hostPlatform.isDarwin then
    "darwin-${if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}"
  else
    "linux-${if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}";
```

This tag is used to name the electron cache symlink that electron-builder expects at `electron-v<version>-<tag>`.

### Build Inputs

```nix
nativeBuildInputs = [ makeWrapper ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ copyDesktopItems ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.autoSignDarwinBinariesHook ];
```

- `copyDesktopItems` - Linux only, installs `.desktop` files
- `darwin.autoSignDarwinBinariesHook` - macOS only, applies ad-hoc code signing (required for Electron on ARM Macs)

### Environment Variables

```nix
env = {
  ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  VSCODE_RIPGREP_VERSION = "system";
} // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
  CSC_IDENTITY_AUTO_DISCOVERY = "false";
};
```

`CSC_IDENTITY_AUTO_DISCOVERY=false` prevents electron-builder from searching for real code signing identities inside the Nix sandbox. Ad-hoc signing via `autoSignDarwinBinariesHook` handles what is needed.

### Build Phase

```nix
npx electron-builder \
  ${if stdenv.hostPlatform.isDarwin then "--mac dir" else "--linux dir"} \
  --${if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"} \
  ...
  ${lib.optionalString stdenv.hostPlatform.isDarwin "--config.mac.identity=null"}
```

- `--linux dir` produces an unpacked directory at `release/<version>/linux-unpacked/`
- `--mac dir` produces a `.app` bundle at `release/<version>/mac/` (x64) or `release/<version>/mac-arm64/` (ARM64)
- `--config.mac.identity=null` disables electron-builder's own code signing on macOS

### Install Phase

**Linux**: Copies resources from the unpacked directory into `$out/opt/heynote/`, creates a `makeWrapper` around the nixpkgs Electron binary pointing at `app.asar`, installs the desktop entry and icon, and adds Wayland/Ozone flags:

```nix
makeWrapper ${lib.getExe electron} $out/bin/heynote \
  --add-flags $out/opt/heynote/resources/app.asar \
  --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto ...}}"
```

**macOS**: Moves `Heynote.app` into `$out/Applications/`, wraps the binary inside the `.app` bundle with `wrapProgram`, and creates a convenience `$out/bin/heynote` via `makeWrapper`:

```nix
wrapProgram "$out/Applications/Heynote.app/Contents/MacOS/Heynote" \
  --set ELECTRON_FORCE_IS_PACKAGED 1 ...
makeWrapper "$out/Applications/Heynote.app/Contents/MacOS/Heynote" "$out/bin/heynote"
```

The `.app` bundle name comes from `productName` in the upstream `package.json`. The output directory glob `mac*/Heynote.app` handles both `mac/` (x64) and `mac-arm64/` (ARM64) variants.

### Desktop Entry

Desktop entry and icon installation are gated to Linux via `lib.optionals stdenv.hostPlatform.isLinux`. macOS discovers applications through the `.app` bundle in `$out/Applications/`.

## Sandbox Workarounds

Several upstream dependencies attempt to download platform-specific binaries during `npm install` or build. These are incompatible with the Nix sandbox and are replaced as follows.

### sass-embedded replaced with sass

The `sass-embedded` package downloads a platform-specific Dart VM binary. The `postPatch` phase rewrites both `package.json` and `package-lock.json` to use the pure JavaScript `sass` package instead. The API is compatible; the only difference is compilation speed.

### @vscode/ripgrep replaced with system ripgrep

Heynote uses `@vscode/ripgrep` for in-app search. This package normally downloads a prebuilt ripgrep binary. The Nix build:

1. Sets `VSCODE_RIPGREP_VERSION=system` to signal the system binary should be used
2. Symlinks the nixpkgs `ripgrep` binary into `node_modules/@vscode/ripgrep/bin/rg` during `preBuild`
3. Replaces `scripts/electron/prepare-rg-universal.js` with a no-op (this script downloads macOS universal ripgrep binaries upstream)
4. Symlinks system ripgrep into the `app.asar.unpacked` directory during `installPhase`

This approach works identically on both platforms. No universal binary is needed since Nix builds per-architecture.

### Binary download prevention

- `ELECTRON_SKIP_BINARY_DOWNLOAD=1` - Prevents Electron binary download (nixpkgs Electron is used)
- `npmFlags = [ "--ignore-scripts" ]` - Skips all postinstall scripts that would attempt binary downloads
- `npm rebuild` in `preBuild` - Rebuilds native modules against Electron headers after scripts are skipped

## Catppuccin Theming

This is a local customisation that replaces Heynote's default Nord-inspired palette with Catppuccin colours. It would be removed for an upstream nixpkgs submission.

Theme patches are applied via `substituteInPlace` in `preBuild`, modifying source files before the Vite build compiles them. All patches are platform-independent text substitutions.

### Patched Files

| Category | Files |
|----------|-------|
| Editor themes | `src/editor/theme/dark.js`, `src/editor/theme/light.js` |
| Global CSS | `src/css/base.sass`, `src/css/autocomplete.sass` |
| Constants | `src/common/constants.js` |
| Settings | `Settings.vue`, `KeyboardBindings.vue`, `KeyBindRow.vue`, `AddKeyBind.vue`, `TabListItem.vue` |
| Dialogs | `BufferSelector.vue`, `LanguageSelector.vue`, `NewBuffer.vue`, `EditBuffer.vue`, `ErrorMessages.vue` |
| Tabs | `TabItem.vue`, `TabBar.vue` |
| Folders | `FolderSelector.vue`, `FolderItem.vue` |

### Dark Theme (Mocha) Colour Mapping

| UI Element | Original (Nord) | Catppuccin Mocha |
|------------|-----------------|------------------|
| Background | `#2e3440` | `#1e1e2e` (base) |
| Dark background | `#252a33` | `#181825` (mantle) |
| Surface | `#3b4252` | `#313244` (surface0) |
| Text | `#d8dee9` | `#cdd6f4` (text) |
| Comment | `#888d97` | `#6c7086` (overlay0) |
| Blue accent | `#81a1c1` | `#89b4fa` (blue) |
| Green accent | `#a3be8c` | `#a6e3a1` (green) |
| Mauve accent | `#b48ead` | `#cba6f7` (mauve) |
| Red accent | `#bf616a` | `#f38ba8` (red) |
| Yellow accent | `#ebcb8b` | `#f9e2af` (yellow) |
| Peach accent | `#d08770` | `#fab387` (peach) |

### Light Theme (Latte) Colour Mapping

| UI Element | Original | Catppuccin Latte |
|------------|----------|------------------|
| Background | `#fff` | `#eff1f5` (base) |
| Surface | `#f4f8f4` | `#ccd0da` (surface0) |
| Mantle | `#efefef` | `#e6e9ef` (mantle) |
| Text | `#000` | `#4c4f69` (text) |
| Blue accent | `#1a557e` | `#1e66f5` (blue) |
| Highlight | `#48b57e` | `#1e66f5` (blue) |

## Updating the Package

When a new Heynote release is available:

1. **Update the version** in `default.nix`:
   ```nix
   version = "2.8.3";  # new version
   ```

2. **Update the source hash** - set `hash` to `lib.fakeHash` and build to get the correct value:
   ```bash
   just build-pkg heynote
   # Copy the expected hash from the error message
   ```

3. **Update the npm dependencies hash** - set `npmDepsHash` to `lib.fakeHash` and build again:
   ```bash
   just build-pkg heynote
   # Copy the expected hash from the error message
   ```

4. **Verify theme patches still apply** - if upstream changed any of the patched source files, the `substituteInPlace` calls using `--replace-fail` will fail at build time, indicating which colour values need updating.

5. **Test the build**:
   ```bash
   just build-pkg heynote && ./result/bin/heynote
   ```

## Known Risks for Upstreaming

These items are relevant if submitting this package to nixpkgs.

### npmDepsHash may need per-platform values

The `npmDepsHash` is computed from `package-lock.json` after the `postPatch` modifications (sass-embedded to sass replacement). Since `npmFlags = [ "--ignore-scripts" ]` prevents platform-specific postinstall scripts, and the sass replacement is platform-independent, the same hash works on both platforms. However, if future dependency updates introduce platform-specific optional dependencies, the hash may diverge:

```nix
npmDepsHash = if stdenv.hostPlatform.isDarwin
  then "sha256-DARWIN_HASH"
  else "sha256-LINUX_HASH";
```

### electron-builder output directory naming

On macOS, electron-builder writes to `mac/` for x64 and `mac-arm64/` for ARM64 builds. The glob `mac*/Heynote.app` handles both, but this naming convention should be verified on each architecture when testing.

### .app bundle executable name

The binary at `Contents/MacOS/Heynote` is assumed from the `productName` field in `package.json`. This follows the same pattern as element-desktop (`Element`) and logseq (`Logseq`). If upstream changes the product name, the `wrapProgram` path will need updating.

### Catppuccin patches are a local customisation

All theme patches in `preBuild` would need to be removed for a clean upstream submission. The build mechanics (sandbox workarounds, platform branching, install phases) are independent of theming.

## Resources

- [Heynote repository](https://github.com/heyman/heynote)
- [Heynote releases](https://github.com/heyman/heynote/releases)
- [Catppuccin palette](https://catppuccin.com/palette)
- [Nixpkgs JavaScript guide](https://nixos.org/manual/nixpkgs/stable/#javascript)
- [electron-builder documentation](https://www.electron.build/)

### Nixpkgs Reference Packages

These packages use similar cross-platform `buildNpmPackage` + `electron-builder` patterns:

- [element-desktop](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/instant-messengers/element/element-desktop/default.nix) - best reference for platform-branched install phases and `autoSignDarwinBinariesHook`
- [logseq](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/misc/logseq/default.nix) - shows `.app` bundle install pattern with `wrapProgram` + `makeWrapper`
- [signal-desktop](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/instant-messengers/signal-desktop/default.nix) - shows `electron.dist` copy pattern

## Licence

This Nix expression follows the same licence as the upstream Heynote project (MIT).
