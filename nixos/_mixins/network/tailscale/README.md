# Tailscale

Auto-joins NixOS hosts to a Tailscale tailnet on boot using OAuth client credentials. No manual key rotation, no 90-day expiry.

```nix
# Activates on workstations and servers automatically via noughty gating:
lib.mkIf (host.is.workstation || host.is.server) { ... }
```

## How it works

The NixOS `services.tailscale` module reads an OAuth client secret from sops-nix and passes it to `tailscale up --auth-key`. Tailscale recognises the `tskey-client-` prefix and handles the OAuth token exchange internally.

On boot, `tailscaled-autoconnect.service` registers the node with `tag:nixos`, which disables key expiry automatically (tagged devices never expire). The `authKeyParameters` option appends `?ephemeral=false&preauthorized=true` to skip manual approval and persist the node.

## Why OAuth over pre-auth keys

| Aspect | Pre-Auth Key | OAuth Client Secret |
|---|---|---|
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
|--------|-----|---------|
| `tailscale-client-id` | `client_id` | OAuth client identifier |
| `tailscale-client-secret` | `client_secret` | OAuth secret passed to `--auth-key` |
| `tailscale-auth-key` | `auth_key` | Legacy pre-auth key, retained for rollback |

Edit secrets with `sops secrets/tailscale.yaml`. ISO builds are excluded from all secret declarations.

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

The `--operator` flag is set to the noughty username, granting that user non-root control of Tailscale.

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
|---|---|---|
| `auth_keys` | Write | Create and delete auth keys, register new nodes. **Required.** |
| `auth_keys:read` | Read | List and inspect auth keys. Included in `auth_keys`. |
| `devices:core` | Write | Delete devices, manage tags, toggle key expiry via API. Not required for registration. |
| `devices:core:read` | Read | List devices. Useful for monitoring only. |

Minimum required: `auth_keys` (Write) with one or more tags.

Optional scopes for future automation: `devices:core` (remove stale devices, change tags), `devices:routes` (approve subnet routes or exit nodes via API), `dns` (manage DNS settings via API).

## Verification

1. Build and switch: `just switch`
2. Confirm the node appears in the Tailscale admin console with the correct tag.
3. Run `tailscale status` and verify the node is connected and not marked ephemeral.

## Rollback

Revert the Nix changes and replace the OAuth secret in sops with a fresh pre-auth key. The `authKeyFile` option accepts both formats transparently.
