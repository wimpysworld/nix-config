{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  electron_39,
  nodejs,
  ripgrep,
  # Command line arguments which are always set
  commandLineArgs ? "",
}:
let
  electron = electron_39;

  # Catppuccin colour palette - defined at let-scope for use in postPatch
  catppuccinMocha = {
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
    surface0 = "#313244";
    surface1 = "#45475a";
    surface2 = "#585b70";
    overlay0 = "#6c7086";
    overlay1 = "#7f849c";
    overlay2 = "#9399b2";
    subtext0 = "#a6adc8";
    subtext1 = "#bac2de";
    text = "#cdd6f4";
    lavender = "#b4befe";
    blue = "#89b4fa";
    sapphire = "#74c7ec";
    sky = "#89dceb";
    teal = "#94e2d5";
    green = "#a6e3a1";
    yellow = "#f9e2af";
    peach = "#fab387";
    maroon = "#eba0ac";
    red = "#f38ba8";
    mauve = "#cba6f7";
    pink = "#f5c2e7";
    flamingo = "#f2cdcd";
    rosewater = "#f5e0dc";
  };

  catppuccinLatte = {
    base = "#eff1f5";
    mantle = "#e6e9ef";
    crust = "#dce0e8";
    surface0 = "#ccd0da";
    surface1 = "#bcc0cc";
    surface2 = "#acb0be";
    overlay0 = "#9ca0b0";
    overlay1 = "#8c8fa1";
    overlay2 = "#7c7f93";
    subtext0 = "#6c6f85";
    subtext1 = "#5c5f77";
    text = "#4c4f69";
    lavender = "#7287fd";
    blue = "#1e66f5";
    sapphire = "#209fb5";
    sky = "#04a5e5";
    teal = "#179299";
    green = "#40a02b";
    yellow = "#df8e1d";
    peach = "#fe640b";
    maroon = "#e64553";
    red = "#d20f39";
    mauve = "#8839ef";
    pink = "#ea76cb";
    flamingo = "#dd7878";
    rosewater = "#dc8a78";
  };
in
buildNpmPackage (finalAttrs: {
  pname = "heynote";
  version = "2.8.2";

  src = fetchFromGitHub {
    owner = "heyman";
    repo = "heynote";
    rev = "v${finalAttrs.version}";
    hash = "sha256-SoEz528bxt+cUkM941Z9O4X2mb3LwoIGAEL504LLQqY=";
  };

  # Use the same Node.js version that Heynote expects
  inherit nodejs;

  # Disable binary downloads for sandbox compatibility
  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    # Tell @vscode/ripgrep to use system ripgrep
    VSCODE_RIPGREP_VERSION = "system";
    # Note: ELECTRON_CACHE is set dynamically in preBuild/build phases with absolute path
  };

  # npm dependencies hash - computed from package-lock.json
  # Updated to use sass instead of sass-embedded (pure JS vs binary-embedded)
  npmDepsHash = "sha256-wER+JuBf60KUE+opvPEYTqeYM1xHAStxETK1GOB7ma4=";

  # Skip scripts during initial npm install to avoid ripgrep download
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];

  # Early patches that need to run in both npm-deps and main build
  postPatch = ''
    # Replace the prepare-rg-universal script with a no-op for Linux
    # We'll use system ripgrep instead
    cat > scripts/electron/prepare-rg-universal.js << 'RGEO'
    // No-op for Nix build - we use system ripgrep
    if (process.platform === 'darwin') {
      console.log('Skipping universal binary preparation on macOS - using system ripgrep');
    }
    RGEO

    # Replace sass-embedded with pure JavaScript sass in package.json
    # sass-embedded downloads platform-specific Dart binaries that don't work in the Nix sandbox
    # The sass package provides the same API but compiles SCSS in pure JavaScript (slower but works in sandbox)
    substituteInPlace package.json --replace-fail '"sass-embedded": "^1.87.0"' '"sass": "^1.87.0"'

    # Remove sass-embedded from package-lock.json and replace with sass
    # This avoids npm install trying to download the platform-specific binary
    if [ -f package-lock.json ]; then
      # Remove the sass-embedded entries from package-lock.json
      ${lib.getExe' nodejs "node"} -e '
        const fs = require("fs");
        const lock = JSON.parse(fs.readFileSync("package-lock.json", "utf8"));

        // Remove sass-embedded packages
        Object.keys(lock.packages || {}).forEach(key => {
          if (key.includes("sass-embedded")) {
            delete lock.packages[key];
          }
        });

        // Remove sass-embedded from dependencies
        if (lock.packages && lock.packages[""] && lock.packages[""].devDependencies) {
          delete lock.packages[""].devDependencies["sass-embedded"];
          lock.packages[""].devDependencies["sass"] = "^1.77.5";
        }

        fs.writeFileSync("package-lock.json", JSON.stringify(lock, null, 2));
        console.log("Replaced sass-embedded with sass in package-lock.json");
      '
    fi

    # Patch package.json to separate vite build from electron-builder
    # This allows us to run electron-builder with our custom configuration
    ${lib.getExe' nodejs "node"} -e '
      const fs = require("fs");
      const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));

      // Replace build script to only do vite build, not electron-builder
      // We will run electron-builder separately with our config
      pkg.scripts.build = "vue-tsc --noEmit && vite build && node scripts/electron/prepare-rg-universal.js";

      fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
      console.log("Patched package.json to separate vite build from electron-builder");
    '
  '';

  # Pre-build setup - runs after npm dependencies are installed
  preBuild = ''
        # Patch @vscode/ripgrep to use system ripgrep (now that node_modules exists)
        if [ -d node_modules/@vscode/ripgrep ]; then
          mkdir -p node_modules/@vscode/ripgrep/bin
          ln -sf ${lib.getExe ripgrep} node_modules/@vscode/ripgrep/bin/rg
        fi

    # Note: sass-embedded was replaced with pure JavaScript sass in postPatch
    # to avoid binary download issues in the Nix sandbox

    # --- CATPPUCCIN MOCHA (DARK) THEME PATCHES ---
        # Based on Nord -> Mocha mapping

        # Polar Night (dark backgrounds) -> Catppuccin Mocha base
        substituteInPlace src/editor/theme/dark.js \
          --replace-fail "const base00 = '#2e3440'" "const base00 = '${catppuccinMocha.base}'" \
          --replace-fail "base01 = '#3b4252'" "base01 = '${catppuccinMocha.surface0}'" \
          --replace-fail "base02 = '#434c5e'" "base02 = '${catppuccinMocha.surface1}'" \
          --replace-fail "base03 = '#4c566a'" "base03 = '${catppuccinMocha.surface2}'"

        # Snow Storm (text/light colors) -> Catppuccin Mocha text
        substituteInPlace src/editor/theme/dark.js \
          --replace-fail "const base04 = '#d8dee9'" "const base04 = '${catppuccinMocha.text}'" \
          --replace-fail "base05 = '#c7cad0'" "base05 = '${catppuccinMocha.subtext1}'" \
          --replace-fail "base06 = '#eceff4'" "base06 = '${catppuccinMocha.subtext0}'"

        # Frost (blues/teals) -> Catppuccin Mocha blue/sapphire/sky/teal
        substituteInPlace src/editor/theme/dark.js \
          --replace-fail "const base07 = '#8fbcbb'" "const base07 = '${catppuccinMocha.teal}'" \
          --replace-fail "base08 = '#88c0d0'" "base08 = '${catppuccinMocha.sapphire}'" \
          --replace-fail "base09 = '#81a1c1'" "base09 = '${catppuccinMocha.blue}'" \
          --replace-fail "base0A = '#5e81ac'" "base0A = '${catppuccinMocha.lavender}'"

        # Aurora (accents) -> Catppuccin Mocha accents
        substituteInPlace src/editor/theme/dark.js \
          --replace-fail "const base0b = '#bf616a'" "const base0b = '${catppuccinMocha.red}'" \
          --replace-fail "base0C = '#d08770'" "base0C = '${catppuccinMocha.peach}'" \
          --replace-fail "base0D = '#ebcb8b'" "base0D = '${catppuccinMocha.yellow}'" \
          --replace-fail "base0E = '#a3be8c'" "base0E = '${catppuccinMocha.green}'" \
          --replace-fail "base0F = '#b48ead'" "base0F = '${catppuccinMocha.mauve}'" \
          --replace-fail "base10 = '#c6c097'" "base10 = '${catppuccinMocha.rosewater}'"

        # Additional UI colors for dark theme
        substituteInPlace src/editor/theme/dark.js \
          --replace-fail "darkBackground = '#252a33'" "darkBackground = '${catppuccinMocha.mantle}'" \
          --replace-fail "background = '#1e222a'" "background = '${catppuccinMocha.base}'" \
          --replace-fail "tooltipBackground = base01" "tooltipBackground = '${catppuccinMocha.surface0}'" \
          --replace-fail "commentColor = '#888d97'" "commentColor = '${catppuccinMocha.overlay0}'"

        # Block colours - make all blocks dark with subtle contrast
        # block-even: base (#1e1e2e) - upper/lower blocks
        # block-odd: mantle (#181825) - middle block (even darker)
        substituteInPlace src/editor/theme/dark.js \
          --replace-fail '"#252B37"' "'${catppuccinMocha.base}'" \
          --replace-fail '"#213644"' "'${catppuccinMocha.mantle}'"

        # Math result colours - use surface colors instead of greenish-teal
        substituteInPlace src/editor/theme/dark.js \
          --replace-fail '"#0e1217"' "'${catppuccinMocha.crust}'" \
          --replace-fail '"#96cbb4"' "'${catppuccinMocha.subtext1}'"

        # --- CATPPUCCIN LATTE (LIGHT) THEME PATCHES ---

        # Background and text
        substituteInPlace src/editor/theme/light.js \
          --replace-fail '"#fff"' "'${catppuccinLatte.base}'" \
          --replace-fail '"#959b98"' "'${catppuccinLatte.surface2}'" \
          --replace-fail '"#8b928e"' "'${catppuccinLatte.surface1}'"

        # Gutter colours
        substituteInPlace src/editor/theme/light.js \
          --replace-fail '"rgba(0,0,0, 0.04)"' "'${catppuccinLatte.mantle}'" \
          --replace-fail '"rgba(0,0,0, 0.25)"' "'${catppuccinLatte.overlay0}'" \
          --replace-fail '"rgba(0,0,0, 0.6)"' "'${catppuccinLatte.text}'"

        # Block colours for light theme
        # Using contrasting colors: base (very light) vs surface0 (light grey)
        # surface0 provides subtle distinction without being too dark
        substituteInPlace src/editor/theme/light.js \
          --replace-fail '"#ffffff"' "'${catppuccinLatte.base}'" \
          --replace-fail '"#f4f8f4"' "'${catppuccinLatte.surface0}'"

        # Selection colours
        substituteInPlace src/editor/theme/light.js \
          --replace-fail '"#77baff8c"' "'${catppuccinLatte.blue}8c'" \
          --replace-fail '"#b2c2ca85"' "'${catppuccinLatte.surface1}85'"

        # Highlight colours for light theme
        substituteInPlace src/editor/theme/light.js \
          --replace-fail '"#906c00"' "'${catppuccinLatte.peach}'" \
          --replace-fail '"#1a557e"' "'${catppuccinLatte.blue}'"

        # --- CATPPUCCIN UI THEME PATCHES (Comprehensive) ---

        # Priority 1: Global CSS Variables (src/css/base.sass)
        # Note: SASS/CSS files use raw hex values (not quoted), so patterns don't have quotes
        # Colors found in upstream source:
        # - #0e1217, #151516, #1b6540, #48b57e (dark theme)
        # - #efefef, #fff, #f4f8f4, #444, #252B37 (light theme)

        # CSS Variable mappings for theme consistency:
        # Light theme: --highlight-color #48b57e -> surface1 (neutral grey, not green)
        # Dark theme: --highlight-color #1b6540 -> surface1 (neutral grey, not green)
        # Note: Split into two separate calls because --draw-element-handle-color appears
        # in both light and dark sections with different replacement values

        # Light theme CSS variables
        substituteInPlace src/css/base.sass \
          --replace-fail "--status-bar-background: #48b57e" "--status-bar-background: ${catppuccinLatte.blue}" \
          --replace-fail "--status-bar-color: #fff" "--status-bar-color: #ffffff" \
          --replace-fail "--highlight-color: #48b57e" "--highlight-color: ${catppuccinLatte.blue}" \
          --replace-fail "--panel-background: #efefef" "--panel-background: ${catppuccinLatte.mantle}" \
          --replace-fail "--tab-bar-border-bottom-color: #d4d4d4" "--tab-bar-border-bottom-color: ${catppuccinLatte.surface1}" \
          --replace-fail "--tab-active-bg: #fff" "--tab-active-bg: ${catppuccinLatte.base}" \
          --replace-fail "--tab-active-bg-blurred: #f4f4f4" "--tab-active-bg-blurred: ${catppuccinLatte.surface0}" \
          --replace-fail "--window-border-color: #6b6b6b" "--window-border-color: ${catppuccinLatte.overlay0}"

        # Dark theme CSS variables
        substituteInPlace src/css/base.sass \
          --replace-fail "--status-bar-background: #0e1217" "--status-bar-background: ${catppuccinMocha.mantle}" \
          --replace-fail "--status-bar-color: rgba(255, 255, 255, 0.75)" "--status-bar-color: ${catppuccinMocha.subtext1}" \
          --replace-fail "--highlight-color: #1b6540" "--highlight-color: ${catppuccinMocha.surface1}" \
          --replace-fail "--panel-background: #151516" "--panel-background: ${catppuccinMocha.surface0}" \
          --replace-fail "--tab-bar-border-bottom-color: #161616" "--tab-bar-border-bottom-color: ${catppuccinMocha.crust}" \
          --replace-fail "--tab-active-bg: #213644" "--tab-active-bg: ${catppuccinMocha.surface1}" \
          --replace-fail "--tab-active-bg-blurred: #1b2b36" "--tab-active-bg-blurred: ${catppuccinMocha.surface0}" \
          --replace-fail "--window-border-color: #000" "--window-border-color: ${catppuccinMocha.crust}"

        # Fix body/editor background in dark mode - use Catppuccin Mocha base
        # The +dark-mode body background was #252B37, should be #1e1e2e (Catppuccin base)
        # This ensures the editor area uses the proper dark background for better contrast
        substituteInPlace src/css/base.sass \
          --replace-fail "background: #252B37" "background: ${catppuccinMocha.base}"

        # Priority 2: Constants (src/common/constants.js) - Tab bar background
        # Colors found in upstream: #1b1c1d, #121313 (dark), #f3f2f2, #e7e7e7 (light)
        # Updated for better contrast: active tab (base) vs tab bar (surface1)
        substituteInPlace src/common/constants.js \
          --replace-fail '"#1b1c1d"' "'${catppuccinMocha.base}'" \
          --replace-fail '"#121313"' "'${catppuccinMocha.mantle}'" \
          --replace-fail '"#f3f2f2"' "'${catppuccinLatte.surface0}'" \
          --replace-fail '"#e7e7e7"' "'${catppuccinLatte.surface1}'"

        # Priority 3: CSS Components
        # autocomplete.sass
        # Note: SASS/CSS files use raw hex values (not quoted), so patterns don't have quotes
        # Colors found in upstream source:
        # - #fff, #ccc, #f1f1f1 (light theme backgrounds/borders) -> Catppuccin Latte
        # - #444 (light theme text) -> Catppuccin Latte text
        # - #202020, #2a2a2a, #333 (dark theme) -> Catppuccin Mocha
        substituteInPlace src/css/autocomplete.sass \
          --replace-fail "#fff" "${catppuccinLatte.base}" \
          --replace-fail "#ccc" "${catppuccinLatte.surface1}" \
          --replace-fail "#f1f1f1" "${catppuccinLatte.surface0}" \
          --replace-fail "#202020" "${catppuccinMocha.surface0}" \
          --replace-fail "#444" "${catppuccinLatte.text}" \
          --replace-fail "#2a2a2a" "${catppuccinMocha.surface1}" \
          --replace-fail "#333" "${catppuccinMocha.surface0}"

        # Priority 4: Vue Component SASS Files
        # Vue files use <style lang="sass"> blocks with unquoted hex colors
        # Only patching colors that actually exist in each file (verified upstream)
        # Note: Order matters - patterns must match exactly with correct CSS property context

        # --- Settings Components ---

        # Settings.vue - Main settings dialog
        # Note: Settings dialog has both light and dark theme versions
        # Light theme colors (for #fff, #eee, #f1f1f1 backgrounds) -> Catppuccin Latte
        # Dark theme colors (for #222, #333 backgrounds) -> Catppuccin Mocha
        substituteInPlace src/components/settings/Settings.vue \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "color: #333" "color: ${catppuccinLatte.text}" \
          --replace-fail "background: #333" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "color: #eee" "color: ${catppuccinMocha.text}" \
          --replace-fail "border-right: 1px solid #eee" "border-right: 1px solid ${catppuccinLatte.surface0}" \
          --replace-fail "border-right: 1px solid #222" "border-right: 1px solid ${catppuccinMocha.surface1}" \
          --replace-fail "background: #f1f1f1" "background: ${catppuccinLatte.surface0}" \
          --replace-fail "color: #555" "color: ${catppuccinLatte.subtext1}" \
          --replace-fail "background: #222" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "background: #eee" "background: ${catppuccinLatte.surface0}" \
          --replace-fail "color: #aaa" "color: ${catppuccinMocha.subtext1}"

        # KeyboardBindings.vue - Keyboard bindings table
        substituteInPlace src/components/settings/KeyboardBindings.vue \
          --replace-fail "background: #f1f1f1" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "border: 2px solid #f1f1f1" "border: 2px solid ${catppuccinMocha.surface0}" \
          --replace-fail "background: #3c3c3c" "background: ${catppuccinMocha.surface2}" \
          --replace-fail "background: #333" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "border: 2px solid #3c3c3c" "border: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "border-bottom: 2px solid #f1f1f1" "border-bottom: 2px solid ${catppuccinMocha.surface0}" \
          --replace-fail "border-bottom: 2px solid #3c3c3c" "border-bottom: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "background: #48b57e" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #fff" "color: ${catppuccinMocha.text}" \
          --replace-fail "background: #1b6540" "background: ${catppuccinMocha.surface0}"

        # KeyBindRow.vue - Individual key binding rows
        substituteInPlace src/components/settings/KeyBindRow.vue \
          --replace-fail "background: #ddd" "background: ${catppuccinMocha.surface2}" \
          --replace-fail "background: #ccc" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "background: #555" "background: ${catppuccinMocha.surface2}" \
          --replace-fail "color: #fff" "color: ${catppuccinMocha.text}" \
          --replace-fail "background: #666" "background: ${catppuccinMocha.surface2}"

        # AddKeyBind.vue - Add key binding dialog
        # Has both light (#fff, #c0c0c0, #ccc, #f1f1f1) and dark (#202020, #2c2c2c) contexts
        substituteInPlace src/components/settings/AddKeyBind.vue \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "border: 2px solid #c0c0c0" "border: 2px solid ${catppuccinLatte.surface1}" \
          --replace-fail "background: #333" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "border: 2px solid #555" "border: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "border: 1px solid #ccc" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "background: #202020" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #fff" "color: ${catppuccinMocha.text}" \
          --replace-fail "border: 1px solid #5a5a5a" "border: 1px solid ${catppuccinMocha.surface2}" \
          --replace-fail "background: #f1f1f1" "background: ${catppuccinLatte.surface0}" \
          --replace-fail "background: #2c2c2c" "background: ${catppuccinMocha.surface1}"

        # --- Dialog/Selector Components ---

        # BufferSelector.vue - Buffer selector dropdown
        # Has both light (#fff, #e2e2e2, #ccc) and dark (#151516, #3b3b3b) contexts
        substituteInPlace src/components/BufferSelector.vue \
          --replace-fail "background: #efefef" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "background: #151516" "background: ${catppuccinMocha.crust}" \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "border: 1px solid #ccc" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "border: 1px solid #fff" "border: 1px solid ${catppuccinLatte.base}" \
          --replace-fail "outline: 2px solid #48b57e" "outline: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "background: #3b3b3b" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "border: 1px solid #5a5a5a" "border: 1px solid ${catppuccinMocha.surface2}" \
          --replace-fail "border: 1px solid #3b3b3b" "border: 1px solid ${catppuccinMocha.surface0}" \
          --replace-fail "background: #e2e2e2" "background: ${catppuccinLatte.surface0}" \
          --replace-fail "background: #29292a" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #fff" "color: ${catppuccinMocha.text}" \
          --replace-fail "background: #48b57e" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #444" "color: ${catppuccinLatte.text}" \
          --replace-fail "background: #1b6540" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "#48b57e" "${catppuccinMocha.surface1}" \
          --replace-fail "#1b6540" "${catppuccinMocha.surface0}"

        # LanguageSelector.vue - Language selector dropdown
        # Has both light (#fff, #ccc, #e2e2e2) and dark (#151516, #3b3b3b) contexts
        substituteInPlace src/components/LanguageSelector.vue \
          --replace-fail "background: #efefef" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "background: #151516" "background: ${catppuccinMocha.crust}" \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "border: 1px solid #ccc" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "border: 1px solid #fff" "border: 1px solid ${catppuccinLatte.base}" \
          --replace-fail "outline: 2px solid #48b57e" "outline: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "background: #3b3b3b" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "border: 1px solid #5a5a5a" "border: 1px solid ${catppuccinMocha.surface2}" \
          --replace-fail "border: 1px solid #3b3b3b" "border: 1px solid ${catppuccinMocha.surface0}" \
          --replace-fail "background: #e2e2e2" "background: ${catppuccinLatte.surface0}" \
          --replace-fail "background: #48b57e" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #fff" "color: ${catppuccinMocha.text}" \
          --replace-fail "background: #29292a" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "background: #1b6540" "background: ${catppuccinMocha.surface0}"

        # NewBuffer.vue - New buffer dialog
        # Has both light (#fff, #ccc, #c5c5c5) and dark (#151516, #3b3b3b) contexts
        substituteInPlace src/components/NewBuffer.vue \
          --replace-fail "background: #efefef" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "background: #151516" "background: ${catppuccinMocha.crust}" \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "border: 1px solid #ccc" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "border: 1px solid #fff" "border: 1px solid ${catppuccinLatte.base}" \
          --replace-fail "outline: 2px solid #48b57e" "outline: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "background: #ffe9e9" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "background: #3b3b3b" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "border: 1px solid #5a5a5a" "border: 1px solid ${catppuccinMocha.surface2}" \
          --replace-fail "border: 1px solid #3b3b3b" "border: 1px solid ${catppuccinMocha.surface0}" \
          --replace-fail "border: 1px solid #c5c5c5" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "outline-color: #48b57e" "outline-color: ${catppuccinMocha.surface2}" \
          --replace-fail "background: #444" "background: ${catppuccinMocha.surface2}"

        # EditBuffer.vue - Edit buffer dialog (identical to NewBuffer.vue)
        # Has both light (#fff, #ccc, #c5c5c5) and dark (#151516, #3b3b3b) contexts
        substituteInPlace src/components/EditBuffer.vue \
          --replace-fail "background: #efefef" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "background: #151516" "background: ${catppuccinMocha.crust}" \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "border: 1px solid #ccc" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "border: 1px solid #fff" "border: 1px solid ${catppuccinLatte.base}" \
          --replace-fail "outline: 2px solid #48b57e" "outline: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "background: #ffe9e9" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "background: #3b3b3b" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "border: 1px solid #5a5a5a" "border: 1px solid ${catppuccinMocha.surface2}" \
          --replace-fail "border: 1px solid #3b3b3b" "border: 1px solid ${catppuccinMocha.surface0}" \
          --replace-fail "border: 1px solid #c5c5c5" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "outline-color: #48b57e" "outline-color: ${catppuccinMocha.surface2}" \
          --replace-fail "background: #444" "background: ${catppuccinMocha.surface2}"

        # ErrorMessages.vue - Error dialog
        # Light theme: #fff background with #333 text
        substituteInPlace src/components/ErrorMessages.vue \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "color: #333" "color: ${catppuccinLatte.text}" \
          --replace-fail "background: #333" "background: ${catppuccinMocha.surface0}" \
          --replace-fail "color: #eee" "color: ${catppuccinMocha.text}" \
          --replace-fail "background: #eee" "background: ${catppuccinLatte.surface0}" \
          --replace-fail "background: #222" "background: ${catppuccinMocha.surface1}"

        # --- Tab Components (Hover Colors Fix) ---

        # TabItem.vue - Tab hover colors (fixing grey hover backgrounds)
        # Light mode hover: #c5c5c5 -> surface1
        # Dark mode hover: #3a3a3a -> surface1
        # Border color: #dbdbdb -> surface0
        substituteInPlace src/components/tabs/TabItem.vue \
          --replace-fail "background: #c5c5c5" "background: ${catppuccinLatte.surface1}" \
          --replace-fail "background-color: #3a3a3a" "background-color: ${catppuccinMocha.surface1}" \
          --replace-fail "border: 1px solid #dbdbdb" "border: 1px solid ${catppuccinLatte.surface0}"

        # TabBar.vue - Main menu and add tab hover colors, title colors
        # Light mode hover: #ccc -> surface1
        # Dark mode hover: #3a3a3a -> surface1
        # Title colors: #444 -> text (light), #aaa -> subtext0 (dark)
        # Blurred title: #888 -> overlay0 (light), #666 -> overlay0 (dark)
        # Border colors: #e6e6e6 -> surface0 (light), #242424 -> surface0 (dark)
        substituteInPlace src/components/tabs/TabBar.vue \
          --replace-fail "background-color: #ccc" "background-color: ${catppuccinLatte.surface1}" \
          --replace-fail "background-color: #3a3a3a" "background-color: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #444" "color: ${catppuccinLatte.text}" \
          --replace-fail "color: #aaa" "color: ${catppuccinMocha.subtext0}" \
          --replace-fail "color: #888" "color: ${catppuccinLatte.overlay0}" \
          --replace-fail "color: #666" "color: ${catppuccinMocha.overlay0}" \
          --replace-fail "border-left: 1px solid #e6e6e6" "border-left: 1px solid ${catppuccinLatte.surface0}" \
          --replace-fail "border-left: 1px solid #242424" "border-left: 1px solid ${catppuccinMocha.surface0}"

        # --- Settings Components (Green Highlight Fix) ---

        # TabListItem.vue - Settings sidebar uses var(--highlight-color)
        # but we need to fix the hover colors
        # Light mode hover: #f1f1f1 -> surface0
        # Dark mode hover: #292929 -> surface1
        substituteInPlace src/components/settings/TabListItem.vue \
          --replace-fail "background: #f1f1f1" "background: ${catppuccinLatte.surface0}" \
          --replace-fail "background: #292929" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #fff" "color: ${catppuccinMocha.text}"

        # --- Folder Selector Components ---

        # FolderSelector.vue - Folder selector
        # Has both light (#fff, #ccc) and dark (#262626) contexts
        substituteInPlace src/components/folder-selector/FolderSelector.vue \
          --replace-fail "background: #fff" "background: ${catppuccinLatte.base}" \
          --replace-fail "border: 1px solid #ccc" "border: 1px solid ${catppuccinLatte.surface1}" \
          --replace-fail "border: 1px solid #fff" "border: 1px solid ${catppuccinLatte.base}" \
          --replace-fail "outline: 2px solid #48b57e" "outline: 2px solid ${catppuccinMocha.surface2}" \
          --replace-fail "background: #262626" "background: ${catppuccinMocha.surface1}" \
          --replace-fail "border: 1px solid #363636" "border: 1px solid ${catppuccinMocha.surface2}"

        # FolderItem.vue - Folder items (uses background-color, not background)
        # Has both light (#f1f1f1) and dark (#39393a) contexts
        substituteInPlace src/components/folder-selector/FolderItem.vue \
          --replace-fail "background-color: #f1f1f1" "background-color: ${catppuccinLatte.surface0}" \
          --replace-fail "background-color: #39393a" "background-color: ${catppuccinMocha.surface1}" \
          --replace-fail "background-color: #48b57e" "background-color: ${catppuccinMocha.surface1}" \
          --replace-fail "color: #fff" "color: ${catppuccinMocha.text}" \
          --replace-fail "background-color: #40a773" "background-color: ${catppuccinMocha.surface2}" \
          --replace-fail "background-color: #1b6540" "background-color: ${catppuccinMocha.surface0}" \
          --replace-fail "background-color: #1f6f47" "background-color: ${catppuccinMocha.surface1}"

        # Copy Electron dist for electron-builder
        cp -r ${electron.dist} electron-dist
        chmod -R u+w electron-dist

    # Set up electron cache for electron-builder with absolute path
    export ELECTRON_CACHE="$PWD/electron-cache"
    mkdir -p "$ELECTRON_CACHE"
    # electron-builder looks for electron-v<version>-linux-x64.zip in ELECTRON_CACHE
    # We create a symlink pointing to the electron dist directory
    ln -sf "$PWD/electron-dist" "$ELECTRON_CACHE/electron-v${electron.version}-linux-x64"

        # Set up npm config for native rebuilds
        export npm_config_nodedir=${electron.headers}
        export npm_config_build_from_source="true"

        # Rebuild native modules with electron headers
        npm rebuild --no-progress --verbose || true
  '';

  # Custom build phase using electron-builder
  buildPhase = ''
    runHook preBuild

    # Ensure ELECTRON_CACHE is set with absolute path
    export ELECTRON_CACHE="$PWD/electron-cache"

    # Build the Vue/Vite app (creates dist/ folder with HTML/CSS/JS)
    npm run build

    # Build with electron-builder using our local electron
    # Point to the electron-builder.json5 config which specifies files to include
    # The config has: files: ["dist-electron", "dist"] - ensuring dist/ is in app.asar
    npx electron-builder \
      --linux dir \
      --x64 \
      --config ./electron-builder.json5 \
      --config.electronDist="$PWD/electron-dist" \
      --config.electronVersion=${electron.version}

    runHook postBuild
  '';

  # Install phase
  installPhase = ''
    runHook preInstall

    # Create output directories
    mkdir -p $out/opt/heynote
    mkdir -p $out/bin
    mkdir -p $out/share/icons/hicolor/256x256/apps
    mkdir -p $out/share/applications

    # Copy icon for desktop entry
    cp resources/icon.png $out/share/icons/hicolor/256x256/apps/heynote.png

    # Copy built application
    # electron-builder outputs to release/${finalAttrs.version}/linux-unpacked/ (dir target)
    # when using electron-builder.json5 config with directories.output set
    cp -r release/${finalAttrs.version}/linux-unpacked/locales $out/opt/heynote/
    cp -r release/${finalAttrs.version}/linux-unpacked/resources $out/opt/heynote/
    cp -r release/${finalAttrs.version}/linux-unpacked/resources.pak $out/opt/heynote/ 2>/dev/null || true

    # Remove auto-update configuration (not applicable for Nix)
    rm -f $out/opt/heynote/resources/app-update.yml || true

    # Link ripgrep from nixpkgs
    mkdir -p $out/opt/heynote/resources/app.asar.unpacked/node_modules/@vscode/ripgrep/bin
    ln -sf ${lib.getExe ripgrep} $out/opt/heynote/resources/app.asar.unpacked/node_modules/@vscode/ripgrep/bin/rg

    # Create wrapper script
    makeWrapper ${lib.getExe electron} $out/bin/heynote \
      --add-flags $out/opt/heynote/resources/app.asar \
      --set ELECTRON_FORCE_IS_PACKAGED 1 \
      --set ELECTRON_IS_DEV 0 \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --add-flags ${lib.escapeShellArg commandLineArgs}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "heynote";
      desktopName = "Heynote";
      exec = "heynote %U";
      terminal = false;
      type = "Application";
      icon = "heynote";
      comment = "A dedicated scratchpad for developers";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
      ];
      startupNotify = true;
      startupWMClass = "heynote";
    })
  ];

  meta = with lib; {
    description = "A dedicated scratchpad for developers (Catppuccin-themed)";
    longDescription = ''
      Heynote is a dedicated scratchpad for developers. It functions as a
      large persistent text buffer where you can write down anything you like.
      This build uses Catppuccin color themes instead of the default Nord palette.
    '';
    homepage = "https://heynote.com/";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode # electron and some node modules
    ];
    mainProgram = "heynote";
  };
})
