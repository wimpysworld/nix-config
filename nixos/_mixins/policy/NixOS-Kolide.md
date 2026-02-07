# Bootstrapping Kolide on NixOS

Kolide provides device trust and compliance monitoring. On NixOS, the
[kolide/nix-agent](https://github.com/kolide/nix-agent) flake provides both the
launcher package and a NixOS module. The declarative configuration lives in
`nixos/_mixins/policy/default.nix`, but the enrollment secret must be obtained
manually before the first deployment.

## Prerequisites

- The target host must be listed in the `installOn` list in
  `nixos/_mixins/policy/default.nix`.
- The host must have sops-nix configured with age keys at
  `/var/lib/private/sops/age/keys.txt`.

## Obtaining the enrollment secret

The enrollment secret is unique to your Kolide tenant. There are two ways to
obtain it.

### Option A: Kolide Slack bot

1. Message the **@Kolide** bot on Slack and type `enroll`.
2. Click **Enroll your device**, then **My employer owns this device**.
3. Choose **Linux (deb)** or **Linux (rpm)** as the installation package.
4. Download the package the bot generates for you.

### Option B: Kolide Device Trust web enrolment

1. Open <https://auth.kolide.com/setup> and sign in with your company email.
2. When prompted to install Kolide, download the Linux deb or rpm package.

## Extracting the secret from the package

### From a .deb file

```bash
nix-shell -p dpkg
mkdir -p /tmp/kolide-extract
dpkg-deb -x /path/to/kolide-launcher.deb /tmp/kolide-extract
cat /tmp/kolide-extract/etc/kolide-k2/secret
```

### From a .rpm file

```bash
nix-shell -p rpm
mkdir -p /tmp/kolide-extract
cd /tmp/kolide-extract
rpm2cpio /path/to/kolide-launcher.rpm | cpio -idmv
cat /tmp/kolide-extract/etc/kolide-k2/secret
```

Copy the secret string - you will need it in the next step.

## Encrypting the secret with sops-nix

The enrollment secret is stored in `secrets/policy.yaml`, encrypted with
sops-nix. The `.sops.yaml` creation rules already cover this path.

### First-time setup (no existing `secrets/policy.yaml`)

```bash
cd ~/Zero/nix-config
sops secrets/policy.yaml
```

sops will open your editor. Add the secret in this format:

```yaml
kolide: <paste-your-enrollment-secret-here>
```

Save and close. sops encrypts the file automatically.

### Updating an existing secret

```bash
cd ~/Zero/nix-config
sops secrets/policy.yaml
```

Edit the `kolide` value, save, and close. sops re-encrypts on save.

### Rekeying after adding new recipients

If you have added new age keys to `.sops.yaml`:

```bash
sops updatekeys secrets/policy.yaml
```

## Deploying the configuration

Build and switch the NixOS configuration on the target host:

```bash
cd ~/Zero/nix-config
just switch
```

This will:

1. Decrypt `secrets/policy.yaml` and place the secret at `/etc/kolide-k2/secret`
   with mode `0600`.
2. Enable and start the `kolide-launcher` systemd service.
3. The launcher connects to `k2device.kolide.com` (the default) and registers
   the device using the enrollment secret.

## Completing enrolment

After the service starts, follow the prompts in the Kolide Slack bot to finish
device verification. If the bot does not pick up the device automatically:

1. Open <https://auth.kolide.com/setup> in a browser.
2. Sign in with your company email.
3. Kolide verifies the device and checks for compliance issues.

## Verifying the service is running

```bash
systemctl status kolide-launcher
journalctl -u kolide-launcher -f
```

## Updating Kolide

The Kolide launcher auto-updates itself and its osquery installation via the
`stable` update channel by default. To pick up a new version of the Nix flake
(which updates the initial launcher binary):

```bash
cd ~/Zero/nix-config
nix flake update kolide-launcher
just switch
```

## Troubleshooting

### Service fails to start

- Check the enrollment secret is present: `sudo cat /etc/kolide-k2/secret`
- Verify sops age keys exist: `sudo ls -la /var/lib/private/sops/age/keys.txt`
- Check the journal: `journalctl -u kolide-launcher -e`

### Device not appearing in Kolide dashboard

- Confirm the service is running and connected:
  `journalctl -u kolide-launcher | grep -i enroll`
- Ensure network connectivity to `k2device.kolide.com` on port 443.

## Architecture notes

- **Flake input**: `kolide-launcher` in `flake.nix` points to
  `github:/kolide/nix-agent/main`.
- **NixOS module**: Imported in `nixos/default.nix` as
  `inputs.kolide-launcher.nixosModules.kolide-launcher`.
- **Policy mixin**: `nixos/_mixins/policy/default.nix` enables the service and
  deploys the secret via sops-nix for hosts in the `installOn` list.
- **Secret storage**: `secrets/policy.yaml` encrypted with age keys defined in
  `.sops.yaml`.
