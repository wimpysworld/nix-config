all_cores := `case "$(uname -s)" in Linux) nproc;; Darwin) sysctl -n hw.logicalcpu;; esac`
build_cores := `printf "%.0f" "$(echo "$(case "$(uname -s)" in Linux) nproc;; Darwin) sysctl -n hw.logicalcpu;; esac) * 0.75" | bc)"`
current_hostname := `hostname -s`
current_username := `whoami`
backup_ext := `date +%Y%m%d-%H%M`

# List recipes
default:
    @just --list --unsorted

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
        # Extract hostname from home config (e.g., "martin.wimpress@bane" -> "bane")
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
    @echo "flake.lock 󱄅 Updating "
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
        --cores "{{ build_cores }}" \
        --option extra-substituters https://install.determinate.systems \
        --option extra-trusted-public-keys "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    elif [ "$(uname)" = "Darwin" ]; then
      echo "nix-darwin 󰀵 Building: {{ hostname }} ({{ build_cores }} cores)"
      nh darwin build . --hostname "{{ hostname }}" -- \
        --option extra-substituters https://install.determinate.systems \
        --option extra-trusted-public-keys "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
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
