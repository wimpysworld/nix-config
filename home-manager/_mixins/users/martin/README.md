# GPG Key Management

Hybrid declarative GPG management using Home Manager for public keys and trust,
with sops-nix for private key import via activation script. An age key at
`~/.config/sops/age/keys.txt` bootstraps sops-nix decryption, so there is no
circular dependency between sops-nix and GPG.

## Key Inventory

| Short ID | Fingerprint | Algorithm | Primary UID | Trust |
|----------|-------------|-----------|-------------|-------|
| `0864983E` | `5E7585ADFF106BFFBBA319DC654B877A0864983E` | DSA (2005) | martin@wimpress.com | full |
| `FFEE1E5C` | `79F9461BF24B27F50DEB8A507454357CFFEE1E5C` | RSA 2048 (2010) | code@flexion.org | full |
| `15E06DA3` | `8F04688C17006782143279DA61DF940515E06DA3` | RSA 4096 (2017) | martin@wimpress.org | ultimate |

## How It Works

### Public keys and trust

Managed declaratively via `programs.gpg.publicKeys` in
`home-manager/_mixins/users/martin/default.nix`. Each key has a `.asc` file in
the same directory, referenced with an explicit trust level. Home Manager runs
`gpg --import` for each key during activation and writes `trustdb.gpg` from the
declared trust levels.

Settings: `mutableKeys = true`, `mutableTrust = false`.

### Private keys

Stored as armoured ASCII exports in `secrets/gnupg.yaml`, encrypted with sops.
A custom `home.activation` script reads the sops-decrypted paths and runs
`gpg --import` for each private key. The `[ -f ]` guard handles the case where
sops has not yet decrypted (first boot).

## Important Caveats

### mutableKeys MUST be true

When `mutableKeys = false`, Home Manager builds `pubring.kbx` at evaluation
time and places it as an immutable Nix store symlink. Running
`gpg --import private-key.asc` needs to update metadata in `pubring.kbx` to
mark the key as having secret material available. An immutable symlink blocks
this write, causing either a permission error or an inconsistent keyring.

With `mutableKeys = true` (the default), `pubring.kbx` is a regular mutable
file that GPG can update freely during private key import.

### mutableTrust = false is safe

When `mutableTrust = false`, Home Manager *copies* `trustdb.gpg` from the Nix
store (not a symlink) with mode 0700. GPG does not modify `trustdb.gpg` during
private key import, so this setting is safe alongside the import activation
script.

### Activation ordering is not guaranteed

The sops-nix Home Manager module triggers an asynchronous
`systemctl restart --user sops-nix` during activation. There is no DAG ordering
guarantee that secrets are decrypted before other activation scripts run.

On first boot, the `[ -f ]` guard in the import script causes private key
import to be silently skipped. A second `home-manager switch` (or manual
import) resolves this. On subsequent rebuilds, secrets from the previous
generation remain available at their symlink paths, so the import succeeds
immediately.

### Never change the GPG homedir from default

The Home Manager GPG module is fragile when the homedir differs from
`~/.gnupg`. Keep the default.

### Never put private key material in publicKeys

Files referenced by `programs.gpg.publicKeys` are copied into the Nix store,
which is world-readable. Only public keys belong there.

## Activation Ordering

The activation sequence for GPG-related steps:

1. **`writeBoundary`** - Home Manager writes config files.
2. **`createGpgHomedir`** - Creates `~/.gnupg` with mode 700.
3. **`linkGeneration`** - Creates symlinks for managed files (`gpg.conf`, `scdaemon.conf`, etc.).
4. **`importGpgKeys`** (Home Manager built-in) - Runs `gpg --import` for each `publicKeys` entry and sets trust. Creates/updates `pubring.kbx` as a regular mutable file. Copies `trustdb.gpg` when `mutableTrust = false`.
5. **`importGpgPrivateKeys`** (custom) - Imports private keys from sops-decrypted paths. GPG updates `pubring.kbx` with secret-key-available flags and writes key material to `private-keys-v1.d/`.
6. **`sops-nix`** - Restarts the sops-nix systemd service. May run in parallel with the above.

Steps 4 and 5 both depend on `linkGeneration`. In practice, the built-in
`importGpgKeys` runs before custom activation scripts. If ordering becomes an
issue, change the custom script to `entryAfter [ "importGpgKeys" ]`.

## Configuration Reference

### Generic GPG and gpg-agent

`home-manager/_mixins/terminal/gpg.nix` - shared by all users:

```nix
{
  config,
  pkgs,
  ...
}:
{
  programs = {
    gpg = {
      enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package =
        if config.wayland.windowManager.hyprland.enable then pkgs.pinentry-gnome3 else pkgs.pinentry-curses;
    };
  };
}
```

### Martin's GPG keys and private key import

GPG-related excerpts from `home-manager/_mixins/users/martin/default.nix`:

```nix
let
  gnupgSopsFile = ../../../../secrets/gnupg.yaml;
in
{
  home = {
    # Import GPG private keys from sops after public keys are in place.
    # Ordered after linkGeneration because Home Manager's importGpgKeys
    # (which handles publicKeys when mutableKeys = true) runs after linkGeneration.
    activation.importGpgPrivateKeys = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      GPG="${pkgs.gnupg}/bin/gpg"

      for PRIVATE in \
        "${config.sops.secrets.gpg_private_0864983E.path}" \
        "${config.sops.secrets.gpg_private_FFEE1E5C.path}" \
        "${config.sops.secrets.gpg_private_15E06DA3.path}"; do
        if [ -f "$PRIVATE" ]; then
          $GPG --batch --yes --pinentry-mode loopback \
            --allow-secret-key-import --import "$PRIVATE" 2>/dev/null || true
        fi
      done
    '';
  };

  programs = {
    # Declarative GPG public keys and trust for Martin's keys.
    # mutableKeys must be true (the default) to allow private key import
    # to update pubring.kbx metadata.
    gpg = {
      mutableKeys = true;
      mutableTrust = false;
      publicKeys = [
        {
          source = ./gpg-pubkey-0864983E.asc;
          trust = "full";
        }
        {
          source = ./gpg-pubkey-FFEE1E5C.asc;
          trust = "full";
        }
        {
          source = ./gpg-pubkey-15E06DA3.asc;
          trust = "ultimate"; # Primary key, used for DEBSIGN
        }
      ];
    };
  };

  # GPG private keys from sops-encrypted gnupg.yaml.
  # Public keys and trust are managed declaratively via programs.gpg.publicKeys above.
  sops.secrets = {
    gpg_private_0864983E.sopsFile = gnupgSopsFile;
    gpg_private_FFEE1E5C.sopsFile = gnupgSopsFile;
    gpg_private_15E06DA3.sopsFile = gnupgSopsFile;
  };
}
```

## Key Management Procedures

### YAML structure in secrets/gnupg.yaml

Each key is stored as a discrete entry, named `gpg_{public|private}_{SHORT_ID}`
where `SHORT_ID` is the last 8 hex characters of the fingerprint:

```yaml
gpg_public_0864983E: |
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    ...
    -----END PGP PUBLIC KEY BLOCK-----
gpg_private_0864983E: |
    -----BEGIN PGP PRIVATE KEY BLOCK-----
    ...
    -----END PGP PRIVATE KEY BLOCK-----
gpg_public_FFEE1E5C: |
    ...
gpg_private_FFEE1E5C: |
    ...
gpg_public_15E06DA3: |
    ...
gpg_private_15E06DA3: |
    ...
```

### Initialising gnupg.yaml

If `secrets/gnupg.yaml` does not exist yet:

```bash
echo "placeholder: init" | sops encrypt \
  --filename-override "secrets/gnupg.yaml" \
  --input-type yaml --output-type yaml /dev/stdin > secrets/gnupg.yaml
```

Then remove the placeholder entry once real keys have been added.

### Exporting a public key

```bash
gpg --export --armor FINGERPRINT > home-manager/_mixins/users/martin/gpg-pubkey-SHORTID.asc
```

Example for key `15E06DA3`:

```bash
gpg --export --armor 8F04688C17006782143279DA61DF940515E06DA3 \
  > home-manager/_mixins/users/martin/gpg-pubkey-15E06DA3.asc
```

These files are safe to commit. Public keys are, by definition, public.

### Exporting a private key to sops

Armour-export the private key, JSON-encode it, and add to `gnupg.yaml`:

```bash
PRIV_JSON=$(gpg --export-secret-keys --armor FINGERPRINT | jq -Rs .)
sops set secrets/gnupg.yaml '["gpg_private_SHORTID"]' "${PRIV_JSON}"
```

The same approach works for public keys stored in `gnupg.yaml`:

```bash
PUB_JSON=$(gpg --export --armor FINGERPRINT | jq -Rs .)
sops set secrets/gnupg.yaml '["gpg_public_SHORTID"]' "${PUB_JSON}"
```

### Enrolling a new key

1. **Identify the fingerprint:**

   ```bash
   gpg --list-keys --keyid-format long
   ```

2. **Derive the short ID** - last 8 hex characters of the fingerprint.

3. **Export the public key to the repository:**

   ```bash
   gpg --export --armor FINGERPRINT > home-manager/_mixins/users/martin/gpg-pubkey-SHORTID.asc
   ```

4. **Export both keys to gnupg.yaml:**

   ```bash
   PUB_JSON=$(gpg --export --armor FINGERPRINT | jq -Rs .)
   sops set secrets/gnupg.yaml '["gpg_public_SHORTID"]' "${PUB_JSON}"

   PRIV_JSON=$(gpg --export-secret-keys --armor FINGERPRINT | jq -Rs .)
   sops set secrets/gnupg.yaml '["gpg_private_SHORTID"]' "${PRIV_JSON}"
   ```

5. **Add the public key to `programs.gpg.publicKeys`** in
   `home-manager/_mixins/users/martin/default.nix`:

   ```nix
   {
     source = ./gpg-pubkey-SHORTID.asc;
     trust = "full";  # or "ultimate" for own primary key
   }
   ```

6. **Add the sops secret** in the same file:

   ```nix
   sops.secrets = {
     gpg_private_SHORTID.sopsFile = gnupgSopsFile;
   };
   ```

7. **Add the path to the activation script's `for` loop.**

8. **Commit** the `.asc` file and updated Nix configuration. The encrypted
   `gnupg.yaml` is committed automatically by `sops set`.

### Updating an existing key

When a key gains new UIDs, subkeys, or signatures, re-export and overwrite:

```bash
# Update gnupg.yaml entries.
PUB_JSON=$(gpg --export --armor FINGERPRINT | jq -Rs .)
sops set secrets/gnupg.yaml '["gpg_public_SHORTID"]' "${PUB_JSON}"

PRIV_JSON=$(gpg --export-secret-keys --armor FINGERPRINT | jq -Rs .)
sops set secrets/gnupg.yaml '["gpg_private_SHORTID"]' "${PRIV_JSON}"

# Update the .asc file in the repository.
gpg --export --armor FINGERPRINT > home-manager/_mixins/users/martin/gpg-pubkey-SHORTID.asc
```

### Removing a key

1. Edit `secrets/gnupg.yaml` directly:

   ```bash
   sops secrets/gnupg.yaml
   ```

   Delete the `gpg_public_SHORTID` and `gpg_private_SHORTID` entries, save,
   and close. sops re-encrypts automatically.

2. Remove the `.asc` file from `home-manager/_mixins/users/martin/`.

3. Remove the `publicKeys` entry, the `sops.secrets` entry, and the path from
   the activation script's `for` loop in
   `home-manager/_mixins/users/martin/default.nix`.

### When to re-export public keys

Re-export the `.asc` file whenever the public key changes:

- New UIDs or subkeys added
- Key signatures updated
- Key expiry extended

```bash
gpg --export --armor FINGERPRINT > home-manager/_mixins/users/martin/gpg-pubkey-SHORTID.asc
```

Also update the public key entry in `gnupg.yaml` at the same time.

## The export-gnupg-keys Script

The `export-gnupg-keys` script at
`home-manager/_mixins/scripts/export-gnupg-keys/` automates the full export
workflow for all three keys: initialises `gnupg.yaml` if needed, exports
public and private keys to sops, and writes the `.asc` files. Run it with:

```bash
export-gnupg-keys
```

All manual steps are documented above and do not depend on this script.
Runtime dependencies: gnupg, jq, sops, coreutils.
