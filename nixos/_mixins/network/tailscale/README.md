# Tailscale

NixOS workstations and servers use one Tailscale daemon. Hosts without the `cg` tag use personal OAuth autoconnect. Hosts with the `cg` tag use manually enrolled, saved profiles instead.

```nix
# Activates on workstations and servers automatically via noughty gating:
lib.mkIf (host.is.workstation || host.is.server) { ... }
```

## How it works

For non-ISO hosts without the `cg` tag, `services.tailscale.authKeyFile` points to the personal OAuth client secret from sops-nix. The NixOS module passes that secret to `tailscale up --auth-key`. Tailscale recognises the `tskey-client-` prefix and handles the OAuth token exchange internally.

At boot, `tailscaled-autoconnect.service` leaves a daemon in the `Running` state alone. It runs `tailscale up` for `NeedsLogin`, `NeedsMachineAuth` or `Stopped`, rather than registering the node on every boot. The command applies `tag:nixos`, which disables key expiry by default. The `authKeyParameters` option appends `?ephemeral=false&preauthorized=true` to skip manual approval and persist the node.

### Account switching on cg hosts

Hosts with the `cg` tag have `authKeyFile = null`. They have no `tailscaled-autoconnect.service`, so the declared `extraUpFlags` do not run. The daemon, tray and secret declarations remain in place. The daemon normally restores the last-selected profile after a restart. Only one tailnet is active at a time.

The work tailnet requires upstream daemon logging, so `cg` hosts set `disableUpstreamLogging = false`. This daemon-wide setting applies when either the personal or work profile is active. Other hosts keep upstream logging disabled.

After the configuration is active, use a local terminal for enrolment and switching. Switching can disconnect a remote session. First inspect the active profile and saved profiles:

```console
tailscale status
tailscale switch --list
```

If the existing personal profile is active, name that profile without replacing its tagged identity:

```console
sudo tailscale set --nickname=personal
```

If no work profile exists, enrol one with the work account:

```console
sudo tailscale login --nickname=work --operator=martin
```

Do not use the personal OAuth secret or `tag:nixos` for work enrolment. Do not log out or reset Tailscale state. If either profile already exists, reuse that profile rather than enrolling it again.

Select the saved profile that you need:

```console
tailscale switch work
tailscale switch personal
```

If the work profile needs subnet routes, select it first, then enable route acceptance for that profile:

```console
sudo tailscale set --accept-routes=true
```

The firewall trusts `tailscale0`. Work peers use that same trust boundary when the work profile is active. Review that access before work enrolment. Personal Caddy availability and certificate renewal depend on the active profile.

See the official [account switching guide](https://tailscale.com/kb/1225/fast-user-switching) and [CLI reference](https://tailscale.com/kb/1080/cli).

## Why OAuth over pre-auth keys

| Aspect | Pre-Auth Key | OAuth Client Secret |
| --- | --- | --- |
| **Lifetime** | 1-90 days (hard cap) | Secret never expires |
| **Rotation required** | Every 90 days maximum | Only if secret is compromised |
| **Manual steps** | Generate key, update sops secret, deploy | One-time setup in admin console |
| **Tags** | Optional | Required (OAuth clients must specify tags) |
| **Node identity** | Authenticated as the generating user | Authenticated as a tagged device (no user identity) |
| **Reusability** | Configurable (one-off or reusable) | Always reusable across nodes |
| **Ephemeral default** | Configurable via `authKeyParameters` | Defaults to ephemeral=true, override with `ephemeral=false` |
| **Security on compromise** | Revoke key in admin console | Revoke OAuth client in admin console |

The only trade-off is that OAuth-registered devices must be tagged, which is appropriate for infrastructure-as-code managed machines.

### Token lifetime details

The OAuth client secret itself has no expiry. OAuth access tokens expire after 1 hour, but this is irrelevant for node registration because `tailscale up` handles token exchange and refresh internally.

Pre-auth keys cannot exceed 90 days. After expiry, existing nodes remain connected until their node key expires (default 180 days), but new nodes cannot register.

## Key expiry and tagged devices

Since March 2022, devices that authenticate with a tag (via `--advertise-tags`) have key expiry disabled automatically. OAuth clients require tags, so every OAuth-registered node gets key expiry disabled without any additional API call or scope.

The `auth_keys` scope alone is sufficient for both registering new nodes and having key expiry disabled. No `devices:core` scope is needed unless you want to programmatically manage devices after registration.

## Secrets

Three sops-nix secrets from `secrets/tailscale.yaml`:

| Secret | Key | Purpose |
| -------- | ----- | --------- |
| `tailscale-client-id` | `client_id` | OAuth client identifier |
| `tailscale-client-secret` | `client_secret` | OAuth secret passed to `--auth-key` |
| `tailscale-auth-key` | `auth_key` | Legacy pre-auth key, retained for rollback |

Edit secrets with `sops secrets/tailscale.yaml`. ISO builds are excluded from all secret declarations. The `cg` exception does not remove any secret declarations.

## Configuration

### Exit nodes

Hosts listed in `tsExitNodes` advertise as exit nodes via `--advertise-exit-node`:

```nix
tsExitNodes = [
  "maul"
  "revan"
];
```

### Caddy integration

When `services.caddy.enable` is true, `permitCertUid` grants Caddy access to acquire TLS certificates from the Tailscale daemon.

### Operator

The `--operator` flag is set to the noughty username, granting that user non-root control of Tailscale. `tailscaled-set.service` applies `extraSetFlags` when that unit runs, not on every profile switch. Set the operator during manual work enrolment as shown above.

## Tailscale ACL prerequisite

The `tag:nixos` tag must exist in your Tailscale ACL policy before deploying:

```json
{
  "tagOwners": {
    "tag:nixos": ["autogroup:admin"]
  }
}
```

## OAuth client setup

1. Open the Tailscale admin console at **Settings > Trust credentials**.
2. Select **Credential**, then **OAuth**.
3. Grant `auth_keys` with **Write** access. No other scopes needed.
4. Add `tag:nixos` under **Tags**.
5. Generate the credential and store both `client_id` and `client_secret` in `secrets/tailscale.yaml`.

### OAuth client scopes reference

| Scope | Access | Purpose |
| --- | --- | --- |
| `auth_keys` | Write | Create and delete auth keys, register new nodes. **Required.** |
| `auth_keys:read` | Read | List and inspect auth keys. Included in `auth_keys`. |
| `devices:core` | Write | Delete devices, manage tags, toggle key expiry via API. Not required for registration. |
| `devices:core:read` | Read | List devices. Useful for monitoring only. |

Minimum required: `auth_keys` (Write) with one or more tags.

Optional scopes for future automation: `devices:core` (remove stale devices, change tags), `devices:routes` (approve subnet routes or exit nodes via API), `dns` (manage DNS settings via API).

## Verification

1. Build and switch: `just switch`
2. For hosts without the `cg` tag, confirm the node appears in the personal Tailscale admin console with `tag:nixos`. For `cg` hosts, follow the manual profile steps above.
3. Run `tailscale status` and verify the node is connected and not marked ephemeral.

## Rollback

Revert the Nix changes and replace the OAuth secret in sops with a fresh pre-auth key. The `authKeyFile` option accepts both formats transparently.
