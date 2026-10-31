# Private Matrix on Malak

Normal NixOS deployment enables Matrix at https://matrix.wimpys.world and provisions the accounts and room automatically. No preparation commands or follow-up configuration changes are required.

Caddy provides public HTTPS on port 443 and forwards Matrix traffic to Tuwunel at `127.0.0.1:6167`. DNS points directly to Malak. Public registration, federation, guests, and room encryption are disabled. Caddy blocks the administration, federation, and server-key endpoints.

## Accounts and room

| Account | Role | Client |
| --- | --- | --- |
| `martin` | Server administrator and room owner | FluffyChat |
| `skrye` | Ordinary user | Moltis on Skrye |
| `zannah` | Ordinary user | Moltis on Zannah |
| `traya` | Ordinary user | Moltis on Momin |

The private, invite-only room is `the-cauldron`, with alias `#the-cauldron:matrix.wimpys.world` and ID `!the-cauldron:matrix.wimpys.world`.

Room version 11 supports Tuwunel's fixed room ID. This lets all clients use the same Nix configuration before the room exists. Martin alone controls room state and invitations. Bots can send messages. History is visible from joining, and federation and encryption are disabled.

## Deployment

`nixos/malak/default.nix` enables `services.privateMatrix`. The `private-matrix-bootstrap` systemd service starts after Tuwunel, waits for its local API, and provisions missing resources. It also runs after Tuwunel restarts. Changes to its code or encrypted credentials restart provisioning during activation.

Credentials already exist in `secrets/matrix.yaml`. SOPS installs root-only files on Malak. Systemd passes the registration secret to Tuwunel through `LoadCredential`. The registration endpoint remains available only through the loopback listener, not public Caddy.

Provisioning verifies existing accounts and room policy without resetting passwords or overwriting conflicting state. A repeated run does not duplicate accounts or rooms. Temporary login tokens stay in memory, use devices distinct from Moltis, and are logged out afterwards. Conflicting state fails the service rather than silently changing access.

Normal Home Manager deployment enables Matrix for Skrye, Zannah, and Traya. Each agent receives only its own runtime password. Stable device IDs avoid new bot devices on every restart. There is no room-ID handoff or separate bootstrap mode.

FluffyChat users select https://matrix.wimpys.world and log in as `martin` with the password stored under `MATRIX_PASSWORD_MARTIN` in SOPS. Phone client installation and human login remain normal client setup, not provisioning steps.

## Scope and recovery

Matrix supports conversation only in the pinned Moltis release. Neither rooms nor direct messages provide model tools or private owner context. Telegram remains the operator channel. Room replies require mentions; avoid instructions that create endless bot replies.

There are no backups or automatic password rotations. Database loss destroys history and sessions. After a Tuwunel restart, provisioning recreates the configured accounts and fixed room, but does not restore old messages or client sessions.

Malak trusts https://cache.tuwunel.chat in addition to its existing caches. This trust applies to all substitutions on that host. The selected Tuwunel package remains the pinned Nixpkgs package, with no source patch.

Validation uses four synthetic provisioning tests, Nix wiring assertions, and Caddy configuration adaptation. Live certificate issuance and client messaging require deployment. Check service failures with `journalctl -u private-matrix-bootstrap`.
