# Heynote (Catppuccin-themed) - Source Build

This directory contains a Nix expression for building Heynote from source with Catppuccin colour themes.

## Overview

This is an alternative to the AppImage-based approach that patches themes after extraction. Building from source allows us to inject Catppuccin colours directly into the theme JavaScript files before compilation, resulting in a cleaner theming solution.

## Status

**🚧 WORK IN PROGRESS** - This package is not yet complete. The structure is in place but requires hash values and testing.

## Build Requirements

To complete this build, you need to obtain the following hash values:

1. **Source hash** (`src.hash`) - Hash of the GitHub repository
2. **npm dependencies hash** (`npmDepsHash`) - Hash of npm dependencies

## Steps to Complete

### Step 1: Update to Stable Release

The current package uses a beta tag (`v2.8.0-beta.4`). Update to the latest stable release:

1. Visit https://github.com/heyman/heynote/releases
2. Find the latest stable version
3. Update `version` in `default.nix`
4. Update `rev` to match the release tag

### Step 2: Get Source Hash

```bash
# Use nix-prefetch-git to get the source hash
nix-prefetch-git --url https://github.com/heyman/heynote --rev refs/tags/v2.8.0
```

Copy the `sha256` value into the `src.hash` field.

### Step 3: Get npm Dependencies Hash

```bash
# Navigate to the nix-config directory
cd ~/Zero/nix-config

# Use prefetch-npm-deps to get the npm hash
nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps https://github.com/heyman/heynote/archive/refs/tags/v2.8.0.tar.gz"
```

Alternatively, attempt the build and copy the hash from the error message:

```bash
just build-pkg heynote
```

The build will fail with a hash mismatch error. Copy the expected hash into `npmDepsHash`.

### Step 4: Build and Test

```bash
# Build the package
just build-pkg heynote

# If successful, test it
./result/bin/heynote
```

## Colour Mapping

The package applies the following Catppuccin colour mappings:

### Dark Theme (Mocha)

| UI Element | Original (Nord) | Catppuccin Mocha |
|------------|-----------------|------------------|
| Background | `#2e3440` | `#1e1e2e` (base) |
| Surface | `#3b4252` | `#313244` (surface0) |
| Text | `#d8dee9` | `#cdd6f4` (text) |
| Blue accent | `#81a1c1` | `#89b4fa` (blue) |
| Green accent | `#a3be8c` | `#a6e3a1` (green) |
| Mauve accent | `#b48ead` | `#cba6f7` (mauve) |

### Light Theme (Latte)

| UI Element | Original | Catppuccin Latte |
|------------|----------|------------------|
| Background | `#fff` | `#eff1f5` (base) |
| Surface | `#f4f8f4` | `#e6e9ef` (mantle) |
| Text | `#000` | `#4c4f69` (text) |

## Known Issues and Solutions

### Ripgrep Binary Download

The `@vscode/ripgrep` package normally downloads platform-specific ripgrep binaries during installation. This is handled by:

1. Setting `VSCODE_RIPGREP_VERSION = "system"` environment variable
2. Replacing the download script with a symlink to the system `ripgrep` package
3. Patching the `prepare-rg-universal.js` script to be a no-op

### Native Module Rebuilds

Native Node.js modules (like `sqlite3`, `better-sqlite3`) need to be rebuilt against Electron's headers. This is handled in the `preBuild` phase by:

1. Setting `npm_config_nodedir` to Electron's headers
2. Running `npm rebuild` with `build_from_source=true`

### Electron Builder Configuration

The build uses `electron-builder` with:
- `--linux dir` to output an unpacked directory
- `--config.electronDist` pointing to the Nix Electron distribution
- `--config.electronVersion` matching the Nixpkgs Electron version

## Comparison with AppImage Approach

| Aspect | AppImage (Current) | Source Build (This) |
|--------|-------------------|---------------------|
| Theme patching | Post-extraction (complex) | Pre-build (clean) |
| Ripgrep handling | Manual extraction | Symlink to nixpkgs |
| Auto-updates | Disabled manually | Disabled (no update.yml) |
| Build time | Fast (download) | Slow (compile) |
| Maintenance | Track AppImage releases | Track npm/Electron |
| Wayland support | Needs patching | Native support |

## Resources

- [Heynote Repository](https://github.com/heyman/heynote)
- [Catppuccin Palette](https://catppuccin.com/palette)
- [Nixpkgs JavaScript Framework Guide](https://nixos.org/manual/nixpkgs/stable/#javascript)
- [Electron Builder Documentation](https://www.electron.build/)

## Alternative Approaches

If building from source proves problematic, consider:

1. **Continuing with AppImage patching** - The existing overlay approach with improved theme file detection
2. **Using a different release format** - Heynote also releases as `.deb` or `.snap` which might be easier to patch
3. **Upstream theming support** - Contributing a Catppuccin theme PR to Heynote itself

## Troubleshooting

### Hash Mismatch Errors

If you see a hash mismatch for `npmDepsHash`:
```
nix-prefetch-npm-deps https://github.com/heyman/heynote/archive/refs/tags/v2.8.0.tar.gz
```

### Build Failures

Enable verbose logging:
```nix
npmFlags = [ "--verbose" ];
```

### Missing Icons

If the application icon is missing, you may need to extract it from the built resources or provide a custom icon file.

## License

This Nix expression follows the same license as the upstream Heynote project (MIT).
