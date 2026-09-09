# Weave on Revan

Weave serves Martin's Syncthing notebook at `/home/martin/Notes`.
It runs as `martin:users`, listens on `127.0.0.1:8000`, and opens no firewall port.
The service creates the `.zk` marker before startup. It does not need the desktop's notebook database.

## Password

`secrets/weave.yaml` stores `WEAVE_PASSWORD` with sops encryption.
Use `sops secrets/weave.yaml` to view or change the password locally.
The service reads it through a systemd credential and refuses an empty password.
Its private filesystem exposes the notebook but hides other home directories.

## Cloudflare Tunnel

Create a dedicated, remotely managed tunnel, as with LibreChat and Gatus.
Configure its published application route in Cloudflare:

| Setting | Value |
| --- | --- |
| Public hostname | `notes.wimpys.world` |
| Service URL | `http://127.0.0.1:8000` |
| Encrypted connector token | `CLOUDFLARE_TUNNEL_TOKEN_WEAVE` in `secrets/cloudflare.yaml` |

Use `sops secrets/cloudflare.yaml` to add the connector token.
The configuration enables `cloudflared-weave.service` only when that encrypted key exists.
Without the token, Weave remains available only on Revan's loopback interface.
Cloudflare stores the route and its fallback, not this repository.

Weave's password protects the notes. No Cloudflare Access policy is declared here.
Configure an Access application for the hostname to restrict access further.

Attachment serving is disabled. Weave 0.1.0 serves `WEAVE_ATTACHMENTS` files without its password check.
Before enabling attachments, protect the entire hostname with Cloudflare Access and select only the attachment subdirectory, never the notebook root.

## Apply

After adding the token and configuring the route, deploy Revan's NixOS configuration:

```bash
just push-host revan
```

Open `https://notes.wimpys.world` and sign in with the password from `secrets/weave.yaml`.
Syncthing sends notebook edits to the other configured devices.
