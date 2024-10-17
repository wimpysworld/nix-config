#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

# Function to read file content and format for YAML
function format_for_yaml() {
    echo "    -----BEGIN OPENSSH PRIVATE KEY-----"
    sed 's/^/    /' "$1" | sed '1d;$d'  # Remove first and last lines, indent the rest
    echo "    -----END OPENSSH PRIVATE KEY-----"
}

if [ -z "${1}" ]; then
    echo "ERROR: No host specified."
    exit 1
fi
HOST="${1}"

if [ -d "$HOME/Vaults/Secrets/ssh" ]; then
  echo "Creating up SSH host keys for $HOST..."
  mkdir -p "$HOME/Vaults/Secrets/ssh/${HOST}" || true
  ssh-keygen -N "" -C "${USER}@${HOST}" -t ed25519 -f "$HOME/Vaults/Secrets/ssh/${HOST}/ssh_host_ed25519_key"
  ssh-keygen -N "" -C "${USER}@${HOST}" -t rsa -b 4096 -f "$HOME/Vaults/Secrets/ssh/${HOST}/ssh_host_rsa_key"

  # Start creating the YAML file
  cat << EOF > "${HOME}/Vaults/Secrets/ssh/${HOST}/${HOST}.yaml"
ssh_host_ed25519_key: |
$(format_for_yaml "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_ed25519_key")
ssh_host_ed25519_key_pub: |
    $(cat "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_ed25519_key.pub")
ssh_host_rsa_key: |
$(format_for_yaml "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_rsa_key")
ssh_host_rsa_key_pub: |
    $(cat "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_rsa_key.pub")
EOF
  echo "$HOST.yaml has been created successfully."
  cat "${HOME}/Vaults/Secrets/ssh/${HOST}/${HOST}.yaml"
  echo
  echo "Copy the above and add to sops-nix using:"
  echo "    sops ${HOME}/Zero/nix-config/secrets/${HOST}.yaml"
  echo
else
  echo "ERROR: The Secrets vault is not mounted."
  exit 1
fi
