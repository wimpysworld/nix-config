build_cores := `printf "%.0f" "$(echo "$(case "$(uname -s)" in Linux) nproc;; Darwin) sysctl -n hw.logicalcpu;; esac) * 0.75" | bc)"`
current_hostname := `hostname -s`
current_username := `whoami`
backup_ext := `date +%Y%m%d-%H%M`

# List recipes
default:
    @just --list --unsorted

# Benchmark Determinate Nix performance features
benchmark hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail

    # Detect platform and set appropriate configuration
    case "$(uname -s)" in
        Linux)
            config_path=".#nixosConfigurations.{{ hostname }}.config.system.build.etc.drvPath"
            config_name="NixOS ({{ hostname }})"
            ;;
        Darwin)
            config_path=".#darwinConfigurations.{{ hostname }}.config.system.build.etc.drvPath"
            config_name="Darwin ({{ hostname }})"
            ;;
        *)
            echo "❌ Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac

    echo "📏 Benchmarking Determinate Nix Performance for $config_name..."

    # Create temporary nix configs
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Standard Nix config
    echo "experimental-features = nix-command flakes"  >  "$temp_dir/nix-standard.conf"
    echo "extra-experimental-features = "              >> "$temp_dir/nix-standard.conf"
    echo "eval-cores = 1"                              >> "$temp_dir/nix-standard.conf"
    echo "lazy-trees = false"                          >> "$temp_dir/nix-standard.conf"

    # Determinate Nix config
    echo "experimental-features = nix-command flakes"  >  "$temp_dir/nix-determinate.conf"
    echo "extra-experimental-features = parallel-eval" >> "$temp_dir/nix-determinate.conf"
    echo "eval-cores = 0"                              >> "$temp_dir/nix-determinate.conf"
    echo "lazy-trees = true"                           >> "$temp_dir/nix-determinate.conf"

    echo "   - Standard Nix:    eval-cores=1, lazy-trees disabled, parallel-eval off"
    echo "   - Determinate Nix: eval-cores=0, lazy-trees enabled,  parallel-eval on"
    echo ""

    # Build nix eval command for evaluation benchmark
    nix_cmd="nix eval $config_path --quiet --option eval-cache false 2>/dev/null"

    # Run hyperfine benchmark with isolated configurations
    hyperfine \
        --warmup 1 \
        --runs 3 \
        --export-markdown "$temp_dir/nix-benchmark-results.md" \
        --export-json "$temp_dir/nix-benchmark-results.json" \
        --command-name "Standard Nix" \
        "NIX_CONFIG=\$(cat $temp_dir/nix-standard.conf) $nix_cmd" \
        --command-name "Determinate Nix" \
        "NIX_CONFIG=\$(cat $temp_dir/nix-determinate.conf) $nix_cmd"

    echo ""
    echo "📊 Results Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Extract and display key metrics from JSON results
    if command -v jq >/dev/null 2>&1 && [ -f "$temp_dir/nix-benchmark-results.json" ]; then
        standard_mean=$(jq -r '.results[0].mean' $temp_dir/nix-benchmark-results.json)
        determinate_mean=$(jq -r '.results[1].mean' $temp_dir/nix-benchmark-results.json)

        # Calculate speedup using bc
        speedup=$(echo "scale=2; $standard_mean / $determinate_mean" | bc)
        percent_faster=$(echo "scale=1; ($standard_mean - $determinate_mean) / $standard_mean * 100" | bc)

        printf "❄️ Standard Nix:    %.3f seconds\n" "$standard_mean"
        printf "🚀 Determinate Nix: %.3f seconds\n" "$determinate_mean"
        printf "📈 Speedup:         %.2fx faster (%.1f%% improvement)\n" "$speedup" "$percent_faster"
    else
        echo "⚠️  Could not parse results (jq not available or results file missing)"
    fi

# Build OS and Home configurations
build:
    @just build-home
    @just build-host

# Build OS and Home configurations
check:
    @nix flake check --show-trace

# Evaluate configurations without building
eval:
    @just eval-flake
    @just eval-configs

# Evaluate flake syntax and structure
eval-flake:
    @echo "Flake 󱄅 Evaluation: syntax and structure"
    @nix flake show --allow-import-from-derivation

# Evaluate all configurations for syntax errors
eval-configs:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Configurations 󱄅 Evaluation: all systems"

    # Evaluate NixOS configurations
    echo "  NixOS configurations:"
    if [[ "$(grep ^ID= /etc/os-release | cut -d'=' -f2)" == "nixos" ]]; then
        for config in $(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r '.[]'); do
            echo "    Evaluating nixosConfigurations.${config}..."
            nix eval .#nixosConfigurations.${config}.config.system.name --quiet >/dev/null
        done
    else
        echo "    Skipping NixOS configurations (not on NixOS)"
        for config in $(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r '.[]'); do
            echo "    Found nixosConfigurations.${config} (evaluation skipped on non-NixOS)"
        done
    fi

    # Evaluate Darwin configurations (only on macOS or with --impure for cross-evaluation)
    echo "  Darwin configurations:"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        for config in $(nix eval .#darwinConfigurations --apply builtins.attrNames --json | jq -r '.[]'); do
            echo "    Evaluating darwinConfigurations.${config}..."
            nix eval .#darwinConfigurations.${config}.config.system.name --quiet >/dev/null
        done
    else
        echo "    Skipping Darwin configurations (not on macOS)"
        for config in $(nix eval .#darwinConfigurations --apply builtins.attrNames --json | jq -r '.[]'); do
            echo "    Found darwinConfigurations.${config} (evaluation skipped on Linux)"
        done
    fi

    # Evaluate Home Manager configurations
    echo "  Home Manager configurations:"

    # Get lists of available system configurations for filtering
    nixos_configs=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r '.[]' | tr '\n' ' ')
    darwin_configs=$(nix eval .#darwinConfigurations --apply builtins.attrNames --json | jq -r '.[]' | tr '\n' ' ')

    for config in $(nix eval .#homeConfigurations --apply builtins.attrNames --json | jq -r '.[]'); do
        # Extract hostname from home config (e.g., "martin@bane" -> "bane")
        hostname=$(echo "$config" | sed 's/.*@//')

        # Check if this home config is for a system we can evaluate on this platform
        should_evaluate=false

        if [[ "$(uname -s)" == "Darwin" ]]; then
            # On macOS, evaluate home configs for Darwin systems
            if echo "$darwin_configs" | grep -q "\b$hostname\b"; then
                should_evaluate=true
            fi
        else
            # On Linux, evaluate home configs for NixOS systems
            if echo "$nixos_configs" | grep -q "\b$hostname\b"; then
                should_evaluate=true
            fi
        fi

        if $should_evaluate; then
            echo "    Evaluating homeConfigurations.${config}..."
            nix eval .#homeConfigurations.${config}.config.home.username --quiet >/dev/null
        else
            echo "    Skipping homeConfigurations.${config} (cross-platform)"
        fi
    done

    echo "🗹 All configurations evaluated successfully"

# Switch OS and Home configurations
switch:
    @just switch-home
    @just switch-host

# Apply OS and Home configurations from FlakeHub Cache
apply:
    @just apply-home
    @just apply-host

# Apply Home configuration from FlakeHub Cache
apply-home username=current_username hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKEREF="wimpysworld/nix-config/*"
    LABEL="Home Manager 󰋜"
    CURRENT_LINK="${HOME}/.local/state/home-manager/gcroots/current-home"

    echo "${LABEL} Checking: {{ username }}@{{ hostname }}"

    # Check availability
    if ! RESOLVED=$(fh resolve "${FLAKEREF}#homeConfigurations.{{ username }}@{{ hostname }}" 2>/dev/null); then
      echo "❌ ${LABEL} configuration for {{ username }}@{{ hostname }} not found on FlakeHub"
      echo "   Has the flake been published with 'include-output-paths: true'?"
      exit 1
    fi

    # Check freshness
    if [ -L "${CURRENT_LINK}" ]; then
      CURRENT=$(readlink "${CURRENT_LINK}")
      if [ "${RESOLVED}" = "${CURRENT}" ]; then
        echo "✅ ${LABEL} {{ username }}@{{ hostname }} is already up to date"
        exit 0
      fi
      echo "${LABEL} Applying: {{ username }}@{{ hostname }}"
      echo "   Current:   ${CURRENT}"
      echo "   Available: ${RESOLVED}"
    else
      echo "${LABEL} Applying: {{ username }}@{{ hostname }} (first run)"
      echo "   Available: ${RESOLVED}"
    fi

    fh apply home-manager "${FLAKEREF}#homeConfigurations.{{ username }}@{{ hostname }}"

# Apply OS configuration from FlakeHub Cache
apply-host hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKEREF="wimpysworld/nix-config/*"

    if [ "$(uname)" = "Linux" ]; then
      CONFIG_TYPE="nixos"
      CONFIG_PATH="nixosConfigurations"
      LABEL="NixOS 󱄅"
    elif [ "$(uname)" = "Darwin" ]; then
      CONFIG_TYPE="nix-darwin"
      CONFIG_PATH="darwinConfigurations"
      LABEL="nix-darwin 󰀵"
    else
      echo "Unsupported OS: $(uname)"
      exit 1
    fi

    echo "${LABEL} Checking: {{ hostname }}"

    # Check availability
    if ! RESOLVED=$(fh resolve "${FLAKEREF}#${CONFIG_PATH}.{{ hostname }}" 2>/dev/null); then
      echo "❌ ${LABEL} configuration for {{ hostname }} not found on FlakeHub"
      echo "   Has the flake been published with 'include-output-paths: true'?"
      exit 1
    fi

    # Check freshness
    if [ -L /run/current-system ]; then
      CURRENT=$(readlink /run/current-system)
      if [ "${RESOLVED}" = "${CURRENT}" ]; then
        echo "✅ ${LABEL} {{ hostname }} is already up to date"
        exit 0
      fi
      echo "${LABEL} Applying: {{ hostname }}"
      echo "   Current:   ${CURRENT}"
      echo "   Available: ${RESOLVED}"
    else
      echo "${LABEL} Applying: {{ hostname }} (first run)"
      echo "   Available: ${RESOLVED}"
    fi

    sudo fh apply "${CONFIG_TYPE}" "${FLAKEREF}#${CONFIG_PATH}.{{ hostname }}"

# Build and Switch Home configuration
home:
    @just build-home
    @just switch-home

# Build and Switch Host configuration
host:
    @just build-host
    @just switch-host

# Build ISO
iso iso_name="console":
    @echo "ISO 󰗮 Building: {{ iso_name }} ({{ build_cores }} cores)"
    @nom build .#nixosConfigurations.iso-{{ iso_name }}.config.system.build.isoImage --cores "{{ build_cores }}"
    @mkdir -p "${HOME}/Quickemu/nixos-iso-{{ iso_name }}" 2>/dev/null
    cp "result/iso/$(head -n1 result/nix-support/hydra-build-products | cut -d'/' -f6)" "${HOME}/Quickemu/nixos-iso-{{ iso_name }}/nixos.iso"
    @chown "${USER}": "${HOME}/Quickemu/nixos-iso-{{ iso_name }}/nixos.iso"
    @chmod 644 "${HOME}/Quickemu/nixos-iso-{{ iso_name }}/nixos.iso"

# Nix Garbage Collection
gc:
    @echo "Garbage 󰩹 Collection"
    nh clean all --keep 5

# Update flake.lock
update:
    @echo "flake.lock 󰈡 Updating "
    nix flake update

# Build a specific package
build-pkg pkg hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate input argument
    if [ -z "{{ pkg }}" ]; then
        echo "Usage: just build-pkg <pkg>"
        echo "Example: just build-pkg firefox"
        exit 1
    fi

    # Detect platform
    case "$(uname -s)" in
        Linux)
            platform="nixos";;
        Darwin)
            platform="darwin";;
        *)
            echo "Unsupported OS: $(uname -s)"
            exit 1;;
    esac

    echo "{{ pkg }} 󰏗 Building: for ${platform} on {{ hostname }} ({{ build_cores }} cores)"
    nom build .#"${platform}"Configurations."{{ hostname }}".pkgs."{{ pkg }}" --cores "{{ build_cores }}"

# Build Home configuration
build-home username=current_username hostname=current_hostname:
    @echo "Home Manager  Building: {{ username }}@{{ hostname }} ({{ build_cores }} cores)"
    @nh home build . --configuration "{{ username }}@{{ hostname }}" -- --cores "{{ build_cores }}"

# Switch Home configuration
switch-home username=current_username hostname=current_hostname:
    @echo "Home Manager  Switching: {{ username }}@{{ hostname }}"
    @nh home switch . --configuration "{{ username }}@{{ hostname }}" --backup-extension {{ backup_ext }}

# Build OS configuration
build-host hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" = "Linux" ]; then
      echo "NixOS  Building: {{ hostname }} ({{ build_cores }} cores)"
      nh os build . --hostname "{{ hostname }}" -- \
        --cores "{{ build_cores }}"
    elif [ "$(uname)" = "Darwin" ]; then
      echo "nix-darwin 󰀵 Building: {{ hostname }} ({{ build_cores }} cores)"
      nh darwin build . --hostname "{{ hostname }}" -- \
        --cores "{{ build_cores }}"
    else
      echo "Unsupported OS: $(uname)"
    fi

# Switch OS configuration
switch-host hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" = "Linux" ]; then
      echo "NixOS  Switching: {{ hostname }}"
      nh os switch . --hostname "{{ hostname }}"
    elif [ "$(uname)" = "Darwin" ]; then
      echo "nix-darwin 󰀵 Switching: {{ hostname }}"
      nh darwin switch . --hostname "{{ hostname }}"
    else
      echo "Unsupported OS: $(uname)"
    fi

# Boot OS configuration (activate on next reboot)
boot-host hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" = "Linux" ]; then
      echo "NixOS ♺  Booting: {{ hostname }}"
      nh os boot . --hostname "{{ hostname }}"
    elif [ "$(uname)" = "Darwin" ]; then
      echo "nix-darwin does not support boot activation. Use 'just switch-host' instead."
    else
      echo "Unsupported OS: $(uname)"
    fi

# Format and lint Nix files
format *paths:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ $# -eq 0 ]; then
      echo "Nix 󰉼 Formatting: all files"
      deadnix --edit .
      statix fix .
      nixfmt-tree
    else
      echo "Nix 󰉼 Formatting: $*"
      deadnix --edit "$@"
      for target in "$@"; do
        statix fix "$target"
      done
      nixfmt "$@"
    fi
