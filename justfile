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
