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
    echo "ERROR: You must provide a name for the FIDO2/WebAuthn key."
    echo "Usage: $0 <key_name>"
    exit 1
fi
KEY="${1}"

if [ -d "${HOME}/Vaults/Secrets/ssh" ]; then
  echo "Plug in your security key now, if you haven't already."
  # shellcheck disable=SC2162
  read -p "Press Enter when ready to continue..."

  echo
  echo "Creating up FIDO2/WebAuthn keys for ${KEY}..."
  ssh-keygen -t ed25519-sk -C "yubikey-${KEY}" -f "${HOME}/Vaults/Secrets/ssh/id_ed25519_sk_${KEY}"

  if [ ! -e "${HOME}/Vaults/Secrets/ssh/id_ed25519_sk_${KEY}" ]; then
    echo "ERROR: The key file does not exist. Please ensure you have created the key."
    exit 1
  fi

  # Start creating the YAML file
  cat << EOF >> "${HOME}/Vaults/Secrets/ssh/keys.yaml"
id_ed25519_sk_${KEY}: |
$(format_for_yaml "$HOME/Vaults/Secrets/ssh/id_ed25519_sk_${KEY}")
id_ed25519_sk_${KEY}_pub: |
    $(cat "${HOME}/Vaults/Secrets/ssh/id_ed25519_sk_${KEY}.pub")
EOF
  echo "keys.yaml has been created successfully."
  cat "${HOME}/Vaults/Secrets/ssh/keys.yaml"
  echo
  echo "1. Run the following:"
  echo "    sops ${HOME}/Zero/nix-config/secrets/keys.yaml"
  echo
  echo "2. Paste in the contents of keys.yaml and save it."
  echo
  echo "3. Add the key basename to Home Manager:"
  echo "    home-manager/_mixins/features/yubikey.nix"
  echo
  echo "4. Add the public key to GitHub and Configure SSO"
  echo "    https://github.com/settings/keys"
  echo
  echo "5. Switch to the update Home Manager:"
  echo "    just switch-home"
  echo
  echo "6. Add the key to the SSH agent (requires the key passphrase):"
  echo "    ssh-add ~/.ssh/id_ed25519_sk_${KEY}"
  echo
  echo "7. List the keys to verify:"
  echo "    ssh-add -L"
  echo "    󰈷 the "
  echo
  echo "8. Run the following, if you haven't already:"
  echo "    gh auth login -p ssh"
else
  echo "ERROR: The Secrets vault is not mounted."
  exit 1
fi
