# RustDesk remote access

The Mac runs the Homebrew RustDesk app with system launchd services. Linux workstations receive the RustDesk Flutter client through Home Manager.

The system agent supports both `LoginWindow` and `Aqua`. The root service preserves configuration across login sessions. Settings remain in writable RustDesk files, outside the Nix store.

## Password

`secrets/rustdesk.yaml` contains a separate, randomly generated RustDesk password. It is not the macOS login password. Native nix-darwin sops-nix decrypts it to `/run/secrets/rustdesk-password`, owned by root with mode `0400`.

Decryption uses the existing user age key at `/Users/<user>/.config/sops/age/keys.txt`. That file must exist before system activation. FileVault must unlock the volume before this key or RustDesk can be available.

To copy the password without printing it, run this command on the Mac from the repository:

```sh
sops decrypt --extract '["password"]' secrets/rustdesk.yaml | pbcopy
```

Paste it into the Linux client's password prompt through your usual password manager. Linux configurations do not install the password. Clear the Mac clipboard after use.

The provisioner reads the secret at runtime and suppresses RustDesk command output. RustDesk accepts the password only as a command argument. Local process inspection can expose it during that short command. The password never enters Nix expressions, generated scripts or service definitions.

## Deployment

Build and switch the Mac system configuration through the repository recipes:

```sh
just build-host momin
just switch-host momin
```

System activation installs the cask, sets root ownership on the app bundle, and applies the secret and settings. Homebrew cask versions are not pinned by `flake.lock`. The service definitions follow RustDesk 1.5.0.

If macOS denies ownership changes, allow the terminal that runs activation in **System Settings > Privacy & Security > App Management**. Then run `just switch-host momin` again. Do not grant Full Disk Access for this error. Activation stops with one error if ownership protection fails. The services and provisioner refuse to execute a user-owned or group-writable app, including after a Homebrew upgrade.

Activation installs the system-wide agent in `/Library/LaunchAgents` and uses `launchctl bootstrap` in the existing user's GUI domain. It does not load an agent into the root system domain. The same plist starts the agent in future `LoginWindow` and `Aqua` sessions. If no GUI domain exists during activation, the agent waits for the next session.

Open RustDesk once and grant the macOS Screen Recording and Accessibility permissions. Do not use RustDesk's service installation or removal controls. Nix owns both service definitions.

The provisioner runs at boot and after system activation. A file lock prevents concurrent runs from applying an old password during secret rotation. It tries five times, with three-second command timeouts and two-second retry delays. It requires RustDesk's password acknowledgement, then applies and reads back the settings in order. Direct access is enabled last. A failure appears in `/var/log/rustdesk-configure.log` at boot, or in activation output.

After correcting a failure, run:

```sh
sudo configure-rustdesk /run/secrets/rustdesk-password
```

On each Linux workstation, build and switch its Home Manager configuration with the existing recipes. No Linux RustDesk server or firewall port is enabled by this module.

## Connection and reboot checks

Use the Mac's LAN address with TCP port `21118`, through the office router's Tailscale subnet route. An exit node alone does not advertise that LAN route. The Mac's own Tailscale app is not required before login through this route.

RustDesk listens on all interfaces. This configuration adds no router forwarding or firewall rules, so local LAN devices can also reach the listener. Direct access does not disable RustDesk's public rendezvous traffic. The connection through Tailscale uses an encrypted tunnel to the subnet router. The final router-to-Mac LAN segment is outside that tunnel.

Use the permanent RustDesk password for remote access. Use the macOS account password at the Mac login screen. Do not store the macOS account password in this RustDesk secret.

Test a normal desktop connection first. Then test the login screen and a reboot while local recovery remains available. A disconnect during login can require a client reconnect. Confirm that permissions still work after a Homebrew upgrade.

FileVault before volume unlock is separate from the ordinary login screen. If FileVault is enabled, use the supported SSH unlock path or local unlock first. RustDesk cannot display the FileVault pre-boot screen.

## Upstream references

- [macOS auto-start setup](https://github.com/rustdesk/rustdesk/wiki/macOS-Auto%E2%80%90Start-Service-Setup-(for-Remote---MDM-Deployment))
- [RustDesk 1.5.0 launch agent](https://github.com/rustdesk/rustdesk/blob/1.5.0/src/platform/privileges_scripts/agent.plist)
- [RustDesk 1.5.0 launch daemon](https://github.com/rustdesk/rustdesk/blob/1.5.0/src/platform/privileges_scripts/daemon.plist)
- [Advanced settings](https://rustdesk.com/docs/en/self-host/client-configuration/advanced-settings/)
- [Homebrew App Management permissions](https://docs.brew.sh/FAQ)
