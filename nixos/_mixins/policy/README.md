# Policy Configurations

NixOS mixin configurations for corporate policy and compliance agents.
Neither Kolide nor CrowdStrike officially supports NixOS as a platform, so
this directory serves as a reference implementation for running both agents
on NixOS declaratively.

## Agents

### Kolide

Device trust and compliance monitoring. Uses the official
[kolide/nix-agent](https://github.com/kolide/nix-agent) flake, which provides
a NixOS module and launcher package. The enrollment secret is deployed via
[sops-nix](https://github.com/Mic92/sops-nix). Once enrolled, Kolide self-updates via its built-in update channel.

### CrowdStrike Falcon

Security monitoring and intrusion detection. CrowdStrike does not officially
support NixOS, so the sensor requires manual installation using pre-built RPM
binaries with patched ELF interpreters. The kernel module backend does not work
on NixOS; the BPF (eBPF) backend is used instead. A custom NixOS module
([`modules/nixos/falcon-sensor.nix`](../../../modules/nixos/falcon-sensor.nix))
manages the systemd service, and a
bootstrap script (`falcon-sensor-install`) handles downloading, extracting,
and patching the sensor binaries.

This is unofficial and unsupported by CrowdStrike.

## Requirements

- Host must be listed in the `installOn` list in `default.nix`
- [sops-nix](https://github.com/Mic92/sops-nix) configured with age keys at `/var/lib/private/sops/age/keys.txt`
- Secrets encrypted in `secrets/policy.yaml`

For CrowdStrike Falcon, the sensor binaries must also be bootstrapped to
`/opt/CrowdStrike/` before the service will start. See the Falcon guide below.

## Detailed Documentation

- [NixOS-Kolide.md](NixOS-Kolide.md) - bootstrap, enrollment, updating, and
  troubleshooting for the Kolide launcher
- [NixOS-Falcon-Sensor.md](NixOS-Falcon-Sensor.md) - bootstrap, installation,
  updating, and troubleshooting for the CrowdStrike Falcon sensor

## Quick Reference

Once secrets are configured and (for Falcon) binaries are bootstrapped,
build and switch your NixOS configuration:

```bash
sudo nixos-rebuild build --flake .
sudo nixos-rebuild switch --flake .
```

Health-check the Falcon sensor at any time with:

```bash
sudo falcon-sensor-check
```
