# Declarative Syncthing Configuration with Home Manager

## Home Manager Syncthing Options

Home Manager provides comprehensive declarative Syncthing configuration via `services.syncthing.settings`:

| Option | Purpose |
|--------|---------|
| `services.syncthing.key` | Path to device private key (key.pem) |
| `services.syncthing.cert` | Path to device certificate (cert.pem) |
| `services.syncthing.settings.devices.<name>.id` | Device ID (public key hash) |
| `services.syncthing.settings.devices.<name>.name` | Human-readable name |
| `services.syncthing.settings.folders.<name>.path` | Folder path (absolute or `~/relative`) |
| `services.syncthing.settings.folders.<name>.devices` | List of device names to share with |
| `services.syncthing.settings.folders.<name>.enable` | Per-host toggle for selective sharing |
| `services.syncthing.overrideDevices` | Delete devices not in config (default: true) |
| `services.syncthing.overrideFolders` | Delete folders not in config (default: true) |

---

## Current Network Inventory

### Devices

All hosts enrolled with fresh keys via `make-syncthing-keys`.

| Device | ID | Type | Folders |
|--------|------|------|---------|
| vader | `TTRWY3V-22LRBHF-7LVDDX7-ADRHXG5-HQJYS5F-K35PUBJ-AXYXKEJ-MGXHNQR` | Workstation | Development, Chainguard, Crypt |
| phasma | `5TRHOB7-UOUNOOX-JJLXYMP-I6ZSL2J-IX2ULR5-X6HPHAD-PZ3I6FF-CWHCTAV` | Workstation | Development, Chainguard, Crypt |
| bane | `X7K3SCU-7KN62YR-NKAZQHW-V2JYRXP-JXGNXFO-QPPPPHX-3MQTO6B-XIK72Q3` | Workstation | Development, Chainguard, Crypt |
| sidious | `ZMYGCVY-ACFU63O-JXDZKLK-ABIKGC7-GWZMBZY-WQKIHCH-RQIUXM6-DM2RKAE` | Workstation | Crypt |
| shaa | `C2GVYBM-C7ORBKW-5EDAJ4R-OFPYMQG-357GAV2-MIMT7EM-DK4X6AS-IQ7HZQF` | Workstation | Crypt |
| tanis | `7VNA2SU-UNVYIFI-UQAXBV5-LZ2F2FQ-TARFAMJ-L4IC5OE-UHQJLRC-UKCV7AB` | Workstation | Development, Crypt |
| atrius | `EKWH3CX-CPKKVGM-KWVNFTJ-AA5GGEU-KR3PRPE-2CC7DBG-K7YXOVO-24GGXAX` | Workstation | Crypt |
| revan | `AVBGEWD-VDVP7JE-T5MHZAG-CZVDIFZ-2F37L7T-IBY4ZIM-O5OOLN3-JV3ZDQA` | Server | Crypt |
| malak | `33YEJHX-NZB34VC-KB3LI2V-HFNOALL-7O2OLEB-SE75AWA-DWOC62K-5SRXMAC` | Server | Crypt |
| maul | `ZEAIH76-MXTIJIT-NAO7XPT-CDGUM4D-PREAAQG-6Z3LVD5-47PB6ZB-KDCRCAS` | Server | Crypt |

### Folders

| Folder ID | Label | Path | Devices |
|-----------|-------|------|---------|
| `6yvmn-vw5xg` | Development | `~/Development` | vader, phasma, bane, tanis |
| `w4kyt-tjgrw` | Chainguard | `~/Chainguard` | vader, phasma, bane |
| `xg5qc-frmdg` | Crypt | `~/Crypt` | All devices |

### Hosts Not Syncing (via Nix)

- krall (darwin)
- momin (darwin, configured manually)

---

## Configuration Strategy

### Device ID Management

Fresh keys are generated for each device using `make-syncthing-keys`. Keys are stored in per-host sops files (`secrets/{hostname}.yaml`). Device IDs will change and need updating in the devices table as hosts are enrolled.

Device IDs are public key hashes - not secrets - and can safely live in Nix config unencrypted.

### Directory Structure

Home Manager uses default locations:
- Config: `~/.config/syncthing`
- Database: `~/.local/state/syncthing`

### Secrets Handling

**Per-host secrets** in `secrets/{hostname}.yaml`:
- `syncthing_key` - Device private key (key.pem contents)
- `syncthing_cert` - Device certificate (cert.pem contents)

**Shared secrets** in `secrets/syncthing.yaml`:
- `apikey` - API key for web interface
- `user` - GUI username
- `pass` - bcrypt-hashed password (for reference)
- `pass_plain` - Plaintext password (required by Home Manager)

Home Manager configuration references the sops paths:

```nix
services.syncthing = {
  key = config.sops.secrets.syncthing_key.path;
  cert = config.sops.secrets.syncthing_cert.path;
};
```

### Security

- **Device IDs**: Safe to publish (public key hashes, not secrets)
- **Private keys** (key.pem): Encrypted in sops, never exposed
- **Certificates** (cert.pem): Also in sops for convenience

### Server Configuration

Servers (revan, malak, maul) will use Home Manager for Syncthing configuration, consistent with workstations.

---

## Enrolling a Host

1. Run `make-syncthing-keys <hostname>` from the nix-config directory
2. Script generates fresh keys and adds them to `secrets/{hostname}.yaml`
3. Script outputs the new device ID
4. Update the devices table in this document with the new ID
5. Update `syncthing-devices.nix` with the new device ID
6. Deploy with `just home`
7. Other devices will need their configs updated to include the new device ID

---

## Proposed Configuration Structure

### syncthing-devices.nix

```nix
{
  devices = {
    vader = { id = "TTRWY3V-22LRBHF-7LVDDX7-ADRHXG5-HQJYS5F-K35PUBJ-AXYXKEJ-MGXHNQR"; };
    phasma = { id = "5TRHOB7-UOUNOOX-JJLXYMP-I6ZSL2J-IX2ULR5-X6HPHAD-PZ3I6FF-CWHCTAV"; };
    bane = { id = "X7K3SCU-7KN62YR-NKAZQHW-V2JYRXP-JXGNXFO-QPPPPHX-3MQTO6B-XIK72Q3"; };
    sidious = { id = "ZMYGCVY-ACFU63O-JXDZKLK-ABIKGC7-GWZMBZY-WQKIHCH-RQIUXM6-DM2RKAE"; };
    shaa = { id = "C2GVYBM-C7ORBKW-5EDAJ4R-OFPYMQG-357GAV2-MIMT7EM-DK4X6AS-IQ7HZQF"; };
    tanis = { id = "7VNA2SU-UNVYIFI-UQAXBV5-LZ2F2FQ-TARFAMJ-L4IC5OE-UHQJLRC-UKCV7AB"; };
    atrius = { id = "EKWH3CX-CPKKVGM-KWVNFTJ-AA5GGEU-KR3PRPE-2CC7DBG-K7YXOVO-24GGXAX"; };
    revan = { id = "AVBGEWD-VDVP7JE-T5MHZAG-CZVDIFZ-2F37L7T-IBY4ZIM-O5OOLN3-JV3ZDQA"; };
    malak = { id = "33YEJHX-NZB34VC-KB3LI2V-HFNOALL-7O2OLEB-SE75AWA-DWOC62K-5SRXMAC"; };
    maul = { id = "ZEAIH76-MXTIJIT-NAO7XPT-CDGUM4D-PREAAQG-6Z3LVD5-47PB6ZB-KDCRCAS"; };
  };

  folders = {
    development = {
      id = "6yvmn-vw5xg";
      path = "~/Development";
      devices = [ "vader" "phasma" "bane" "tanis" ];
    };
    chainguard = {
      id = "w4kyt-tjgrw";
      path = "~/Chainguard";
      devices = [ "vader" "phasma" "bane" ];
    };
    crypt = {
      id = "xg5qc-frmdg";
      path = "~/Crypt";
      devices = [ "vader" "phasma" "bane" "sidious" "shaa" "tanis" "atrius" "revan" "malak" "maul" ];
    };
  };
}
```

### default.nix Pattern

```nix
{ config, hostname, lib, ... }:
let
  syncDefs = import ./syncthing-devices.nix;
  
  # Filter devices: exclude self
  otherDevices = lib.filterAttrs (name: _: name != hostname) syncDefs.devices;
  
  # Filter folders: only enable folders where this host is listed
  hostFolders = lib.mapAttrs (name: folder: folder // {
    enable = lib.elem hostname folder.devices;
    devices = lib.filter (d: d != hostname) folder.devices;
  }) syncDefs.folders;
in
{
  services.syncthing = {
    enable = true;
    key = config.sops.secrets.syncthing_key.path;
    cert = config.sops.secrets.syncthing_cert.path;
    overrideDevices = true;
    overrideFolders = true;
    
    settings = {
      devices = otherDevices;
      folders = hostFolders;
      options = {
        urAccepted = -1;
        relaysEnabled = true;
        localAnnounceEnabled = true;
      };
    };
  };
}
```

---

## Migration Plan

### Phase 1: Enroll hosts ✓

All hosts enrolled with `make-syncthing-keys`. Device IDs updated above.

### Phase 2: Deploy with overrides disabled

1. Set `overrideDevices = false` and `overrideFolders = false`
2. Deploy to all hosts - declarative config merges with existing

### Phase 3: Enable overrides

1. Set `overrideDevices = true` and `overrideFolders = true`
2. Deploy - Nix becomes authoritative
3. Remove legacy `~/Syncthing` directory from all hosts

---

## Limitations and Gotchas

| Issue | Mitigation |
|-------|------------|
| Folder ID mismatch | Folder IDs extracted from existing config - must match exactly |
| Password handling | Using `pass_plain` in sops for Home Manager compatibility |
| Device ID changes | After enrolling with fresh keys, all other devices need the new ID |
