# Defold Source Build Feasibility Assessment

This document analyses the feasibility of building Defold from source in Nix,
compared to the current approach of repackaging upstream binary releases.

## Executive Summary

**Verdict: A true source build of Defold in Nix is technically possible but
extremely complex and likely impractical.**

The current binary repackaging approach is recommended for the following reasons:

1. **Complex multi-language build system** requiring Python, Java/Clojure, C/C++,
   and platform-specific toolchains
2. **Extensive vendored dependencies** in the `packages/` directory that must be
   extracted during the build process
3. **Editor requires pre-built engine artifacts** creating a circular dependency
4. **Extensive platform SDK requirements** (some proprietary)

## Build System Overview

### Dual Build Systems

Defold uses **two complementary build systems**:

1. **Waf (Primary)**: Python-based build system for the engine
   - Entry point: `scripts/build.py` (wrapper) or `waf` directly
   - Configuration: `build_tools/waf_dynamo.py`, `share/wscript`
   - Handles C/C++ compilation, linking, and packaging

2. **CMake (Secondary)**: Used for IDE solution generation
   - File: `CMakeLists.txt` (top-level)
   - Currently only covers `engine/platform`, `engine/hid`, `engine/input`
   - Used for Xcode/Visual Studio project generation via `make_solution` command

### Editor Build System

The editor uses **Clojure/Leiningen**:
- File: `editor/project.clj`
- JavaFX 25 for the UI
- JOGL (Java OpenGL) for graphics
- Can be built standalone (with pre-built engine) or with local engine

## Key Build Dependencies

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.10+ | Build scripts, waf integration |
| Java JDK | 25 (Temurin) | Editor, Bob tool, Clojure |
| Clang | 16+ | Native compilation (Linux, cross-compile to macOS) |
| Git | Any | Version control |
| CMake | 4.0+ | IDE solutions, some engine components |
| Ninja | Any | CMake builds |
| ccache | Optional | Build acceleration |

### Platform-Specific SDKs

| Target Platform | Required SDK | Proprietary? |
|-----------------|--------------|--------------|
| x86_64-linux | Clang toolchain | No |
| arm64-linux | Clang toolchain | No |
| x86_64-macos | Xcode + macOS SDK | **Yes** (Apple) |
| arm64-macos | Xcode + macOS SDK | **Yes** (Apple) |
| arm64-ios | Xcode + iOS SDK | **Yes** (Apple) |
| x86_64-ios | Xcode + iOS Simulator SDK | **Yes** (Apple) |
| x86_64-win32 | Visual Studio 2022 + Windows SDK | **Yes** (Microsoft) |
| win32 | Visual Studio 2022 + Windows SDK | **Yes** (Microsoft) |
| armv7-android | Android NDK + SDK | No (Apache 2.0) |
| arm64-android | Android NDK + SDK | No (Apache 2.0) |
| js-web | Emscripten SDK | No (MIT/LLVM) |
| wasm-web | Emscripten SDK | No (MIT/LLVM) |
| wasm_pthread-web | Emscripten SDK | No (MIT/LLVM) |

### Console Platforms (Proprietary)

- `arm64-nx64` (Nintendo Switch) - **Proprietary SDK required**
- `x86_64-ps4` (PlayStation 4) - **Proprietary SDK required**
- `x86_64-ps5` (PlayStation 5) - **Proprietary SDK required**
- `x86_64-xbone` (Xbox) - **Proprietary SDK required**

These platforms require `build_vendor.py` with vendor-specific SDK access.

## Vendored Dependencies (packages/)

The `packages/` directory contains **pre-built binary libraries** that are
extracted during the build process:

### Core Libraries (All Platforms)
- `protobuf-3.20.1` - Protocol Buffers
- `luajit-2.1.0-3e223cb` - LuaJIT
- `bullet-2.77` - Bullet Physics
- `glfw-3.4` / `glfw-2.7.1` - OpenGL Window/Input
- `box2d-3.1.0` / `box2d_defold-2.2.1` - Box2D Physics
- `vpx-1.7.0` - VP8/VP9 Video Codec
- `tremolo-b0cb4d1` - Ogg Vorbis Decoder
- `openal-1.1` - OpenAL Audio

### Graphics/Shader Libraries
- `vulkan-v1.4.307` - Vulkan SDK
- `spirv-cross-97709575` - SPIR-V Cross Compiler
- `spirv-tools-b21dda0e` / `spirv-tools-d24a39a7` - SPIR-V Tools
- `glslang-42d9adf5` / `glslang-ba5c010c` - GLSL Compiler
- `moltenvk-1474891` - MoltenVK (Vulkan on macOS/iOS)
- `tint-22b958` / `tint-7bd151a780` - WebGPU Tint Compiler
- `astcenc-30aabb3` - ASTC Texture Compression
- `sassc-5472db213ec223a67482df2226622be372921847` - SASS Compiler

### Font/Text Libraries
- `harfbuzz-11.3.2` - Text Shaping
- `SheenBidi-2.9.0` - Bidirectional Text
- `libunibreak-6.1` - Line Breaking
- `SkriBidi-1e8038` - Complex Text Layout

### Audio
- `opus-1.5.2` - Opus Audio Codec

### Build Tools
- `waf-2.1.9` - Waf build system itself
- `lipo-4c7c275` - Universal binary tool (macOS)
- `cctools-port-darwin19-*` - macOS tools for Linux cross-compile

### Java/Maven
- `maven-3.0.1` - Maven build tool
- `junit-4.6` - Testing framework
- `jsign-4.2` - Java signing tool
- `protobuf-java-3.20.1` - Protocol Buffers Java
- Various `.whl` files for Python dependencies

## Build Process Analysis

### Standard Build Flow

```
1. ./scripts/build.py shell           # Setup DYNAMO_HOME environment
2. ./scripts/build.py install_ext      # Extract all packages/
3. ./scripts/build.py check_sdk        # Verify SDK availability
4. ./scripts/build.py build_engine     # Build engine + run tests
5. ./scripts/build.py build_bob        # Build Bob command-line tool
6. ./scripts/build.py build_builtins   # Build builtin resources
7. ./scripts/build.py build_docs       # Generate API documentation
8. cd editor && lein init && lein run  # Build and run editor
```

### Critical Build Steps

#### 1. `install_ext` - Package Extraction

The build system expects to extract pre-built tarballs from `packages/`:

```python
# From build.py
PACKAGES_ALL=[
    "protobuf-3.20.1",
    "luajit-2.1.0-3e223cb",
    "bullet-2.77",
    # ... 20+ more packages
]

PLATFORM_PACKAGES = {
    'x86_64-linux': PACKAGES_LINUX_X86_64,
    'arm64-linux': PACKAGES_LINUX_ARM64,
    # ... per-platform package lists
}
```

**Challenge**: These packages are pre-built binaries. To do a true source build,
each of these would need to be built from source or replaced with Nix packages.

#### 2. SDK Installation

The `install_sdk` command downloads proprietary SDKs:

```python
def install_sdk(self):
    # macOS SDK
    download_sdk(self, '%s/%s.tar.gz' % (self.package_path, sdk.PACKAGES_MACOS_SDK), ...)
    # iOS SDK  
    download_sdk(self, '%s/%s.tar.gz' % (self.package_path, sdk.PACKAGES_IOS_SDK), ...)
    # Windows SDK
    download_sdk(self, '%s/%s.tar.gz' % (self.package_path, sdk.PACKAGES_WIN32_SDK_10), ...)
    # Android NDK
    download_sdk(self, '%s/%s-%s.tar.gz' % (self.package_path, PACKAGES_ANDROID_NDK, host), ...)
    # Emscripten
    download_sdk(self, '%s/%s-%s.tar.gz' % (self.package_path, sdk.PACKAGES_EMSCRIPTEN_SDK, self.host), ...)
```

**Challenge**: SDKs must be provided via `DM_PACKAGES_URL` or `--package-path`.
Many are proprietary and cannot be redistributed.

#### 3. Editor Build

The editor has **two build modes**:

**Mode A: With Pre-built Engine (Recommended)**
```bash
cd editor
lein init <sha1>  # Downloads engine artifacts from GitHub releases
lein run
```

**Mode B: With Local Engine**
```bash
# Build engine first (see above)
./scripts/build.py build_engine
./scripts/build.py build_bob --keep-bob-uncompressed

cd editor
lein init        # Uses local $DYNAMO_HOME
lein run
```

**Challenge**: Mode B requires the engine to be built first, but the editor
wants to use `bob.jar` which needs the engine. There's a dependency cycle.

## Blockers for Nix Source Build

### 1. Pre-built Package Dependencies

The build system is designed around extracting pre-built packages. While some
libraries (bullet, box2d, glfw, protobuf) could be replaced with Nix packages,
others are Defold-specific builds:

- `luajit-2.1.0-3e223cb` - Specific LuaJIT revision with Defold patches
- `tremolo-b0cb4d1` - Custom Ogg Vorbis decoder
- `moltenvk-1474891` - Specific MoltenVK build
- `lipo-4c7c275` - Custom universal binary tool
- `defold-robot-0.7.0` - Defold's testing tool

**Assessment**: 15-20 packages would need to be built from source, requiring
significant effort to reproduce Defold's exact build configuration.

### 2. Circular Dependency (Engine ↔ Editor)

The editor build process:
1. Needs `bob.jar` (built from `com.dynamo.cr/`)
2. `bob.jar` needs engine artifacts (libraries + dmengine)
3. Engine artifacts need the full engine build
4. Full engine build takes 30+ minutes on CI

The Defold team's own CI builds the engine first, then Bob, then the editor.
This would need to be replicated in Nix.

### 3. Platform SDK Licensing

For a complete build supporting all platforms:

| SDK | License | Redistributable? |
|-----|---------|------------------|
| macOS SDK | Apple SLA | **No** |
| iOS SDK | Apple SLA | **No** |
| Xcode Toolchain | Apple SLA | **No** |
| Visual Studio | Microsoft EULA | **No** |
| Windows SDK | Microsoft License | **No** |
| Nintendo Switch SDK | Nintendo NDA | **No** |
| PlayStation SDK | Sony NDA | **No** |
| Xbox SDK | Microsoft NDA | **No** |

**Assessment**: A full source build would only be possible for Linux, Android,
and Web targets without accepting proprietary SDKs.

### 4. Waf Build System Complexity

The waf build system is heavily customised:

```python
# From waf_dynamo.py - 1500+ lines

def default_flags(self):
    # Platform-specific compiler flags
    # SDK detection and configuration
    # Framework linking (macOS)
    # Cross-compilation support
    # Address/UB/Thread sanitizer support
```

**Challenge**: Replicating this in Nix would require either:
- Using waf within Nix (possible but complex)
- Translating all waf rules to Nix expressions (massive effort)

### 5. Editor Java Dependencies

The editor uses several Defold-specific Java libraries:

```clojure
;; From editor/project.clj
[com.defold.lib/bob "1.0"]          ; Built from com.dynamo.cr/
[com.defold.lib/openmali "1.0"]     ; Custom OpenGL math library
[com.defold.lib/icu4j "1.0"]        ; Custom ICU4J build
```

These are installed as local JARs during the build process.

## What Would Be Required for Source Build

### Phase 1: Bootstrap Dependencies (Complex)

Build all `packages/` from source:

1. Create Nix expressions for each vendored library
2. Ensure exact version matching (Defold is sensitive to versions)
3. Handle Defold-specific patches (especially LuaJIT)
4. Build waf itself

### Phase 2: Engine Build (Feasible but Slow)

```nix
stdenv.mkDerivation {
  name = "defold-engine";
  
  nativeBuildInputs = [ 
    python3 
    waf 
    clang 
    cmake 
    ninja
    jdk25
  ];
  
  buildPhase = ''
    export DYNAMO_HOME=$out
    python scripts/build.py install_ext --platform=x86_64-linux
    python scripts/build.py build_engine --platform=x86_64-linux --skip-tests
  '';
}
```

**Estimated time**: 30-60 minutes per platform (based on CI times)

### Phase 3: Bob Build (Feasible)

Bob is a Gradle-based Java build in `com.dynamo.cr/com.dynamo.cr.bob/`:

```bash
./com.dynamo.cr/com.dynamo.cr.bob/gradlew build
```

### Phase 4: Editor Build (Complex)

Requires:
1. Clojure/Leiningen setup
2. JavaFX 25 with native libraries
3. JOGL native libraries for Linux
4. Integration with built engine artifacts

```nix
# Conceptual - not working code
leiningsetup = {
  buildPhase = ''
    cd editor
    lein protobuf
    lein sass once
    lein javac
    lein compile
    lein uberjar
  '';
}
```

## Alternative: Hybrid Approach

A compromise between binary repackaging and full source build:

1. **Use upstream engine binaries** (current approach)
2. **Build editor from source** using `lein init <sha1>`
3. This would allow custom editor builds while using tested engine binaries

**Challenge**: The editor is typically distributed as a complete bundle
(Defold-x86_64-linux.tar.gz) with embedded engine binaries.

## Conclusion

### Recommended Approach: Continue Binary Repackaging

The current approach of repackaging upstream releases is the most practical:

1. **Proven**: The existing Nix package works well
2. **Fast**: No 1+ hour build times
3. **Reliable**: Uses Defold's tested binaries
4. **Complete**: Supports all platforms Defold supports

### If Source Build is Desired

Consider these incremental steps:

1. **Build external libraries from source** (packages/ directory)
   - Start with open-source libraries (bullet, box2d, glfw)
   - Use Nix packages where versions match
   - Build Defold-specific libraries (luajit, tremolo)

2. **Create a "lite" source build**
   - Linux x86_64 only
   - No editor (engine + Bob only)
   - No cross-compilation SDKs

3. **Full source build**
   - Would require significant ongoing maintenance
   - Estimated 500+ lines of Nix expression
   - Build time: 1-2 hours
   - Testing burden: High

### Final Assessment

| Approach | Effort | Build Time | Maintenance | Recommendation |
|----------|--------|------------|-------------|----------------|
| Binary repackaging | Low | Minutes | Low | **Current - Keep** |
| Engine source only | High | 30-60 min | Medium | Possible |
| Full source build | Very High | 1-2 hours | High | Not recommended |

**Bottom line**: Defold's build system is designed around a specific workflow
that assumes access to pre-built packages and proprietary SDKs. While a source
build is technically possible, it would require substantial effort to maintain
and would likely break frequently with upstream changes.

The binary repackaging approach, while not ideologically pure, provides a
working Defold installation that serves NixOS users effectively.

## References

- Defold Repository: https://github.com/defold/defold
- Build Instructions: https://github.com/defold/defold/blob/dev/README_BUILD.md
- Setup Instructions: https://github.com/defold/defold/blob/dev/README_SETUP.md
- Editor Build: https://github.com/defold/defold/blob/dev/editor/README_BUILD.md
