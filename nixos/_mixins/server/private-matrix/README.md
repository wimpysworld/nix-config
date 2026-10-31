# Private Matrix on Malak

This module prepares a private Matrix server for shared text conversation between Martin, Skrye, Zannah, and Traya. Moltis remains on the agent hosts.

> [!IMPORTANT]
> `services.privateMatrix.enable` defaults to `false`. Preparation does not authorise activation, account creation, DNS changes, OAuth sign-in, or secret writes.

## Network and certificate

| Setting | Value |
| --- | --- |
| Canonical `server_name` | `matrix.wimpys.world` |
| Client homeserver URL | `https://matrix.wimpys.world:8443` |
| Tuwunel listener | `127.0.0.1:6167` |
| Private Caddy listener | Port `8443`, bound to explicit Tailnet addresses |
| Public HTTP hostname | `matrix.wimpys.world`, response `404` only |

When this module is enabled, Caddy waits for `tailscaled-autoconnect.service` to report that Tailscale is running before it starts.

The private Caddy listener checks the client's remote address against Tailnet ranges before forwarding requests. Existing public HTTPS sites on port `443` remain unchanged. The public HTTP hostname overrides automatic redirection with `404`.

Publish a DNS-only A record that resolves to Malak's Tailnet IPv4 address. Do not publish an AAAA record for this implementation. Do not enable the Cloudflare proxy or a Cloudflare Tunnel. DNS resolution does not grant network access. Restrict Tailnet access to the intended clients and port `8443`.

Certificate issuance uses the DNS-01 challenge through Cloudflare, not a public Matrix listener. Prepare a dedicated token with DNS Edit and Zone Read permissions for the `wimpys.world` zone only. Do not reuse the broad account token.

The SOPS key is `CLOUDFLARE_DNS_API_TOKEN_MATRIX` in `secrets/cloudflare.yaml`. The module supplies the token file to ACME, the certificate automation service. Keep the token out of Nix values, commands, logs, and client settings.

## Enablement inputs

| Option | Requirement |
| --- | --- |
| `services.privateMatrix.enable` | Explicit approval before setting `true` |
| `services.privateMatrix.listenAddresses` | Non-empty list of literal Malak Tailnet addresses accepted by the module |
| `services.privateMatrix.acmeEmail` | Explicit certificate contact address, default `null` |
| `security.acme.acceptTerms` | Separate user consent before setting `true` |

The module requires Malak and enabled Tailscale. No certificate contact is selected. Ask the user for the contact address instead of assuming the existing Caddy contact. The module does not accept ACME terms on the user's behalf.

The current source accepts only IPv4 addresses within `100.64.0.0/10` in `listenAddresses`. Its remote-address guard also includes the Tailnet IPv6 range. Do not supply an IPv6 bind until the module supports that input.

## Operator onboarding after approval

These steps are a later operator procedure, not instructions for an agent to execute during preparation.

1. Confirm Malak's literal Tailnet bind addresses.
2. Ask the user for the certificate contact address and separate ACME terms consent.
3. Prepare the dedicated Cloudflare token and SOPS recipient access.
4. Publish the DNS-only A record after approval.
5. Review and build the enabled configuration before a separately approved deployment.
6. Use local Tuwunel administration to create the human administrator first.
7. Create three non-administrator accounts for Skrye, Zannah, and Traya.
8. Verify account privileges before issuing the bot tokens.
9. Create an invite-only, unlisted, unencrypted room as the human administrator.
10. Keep room invitation rights with the human, not the bot accounts.
11. Invite the three bot accounts and record the real room ID.
12. Sign in each bot account to obtain its own Matrix access token.
13. Store the tokens through the approved SOPS workflow.
14. Set each agent's Matrix options with its account ID and the shared room ID.

Keep public registration and federation disabled throughout onboarding. The module also disables room encryption and unauthenticated public room discovery. Do not enable registration as a shortcut for account creation.

Use the [Tuwunel configuration and local administration guide](https://matrix-construct.github.io/tuwunel/configuration.html) for the bootstrap procedure. Confirm the command syntax against the installed Tuwunel `1.9.4` help before use. This guide deliberately gives no unverified bootstrap command or temporary production configuration. Protect bootstrap output because account creation can print passwords.

See the [Moltis Matrix setup](../../../../home-manager/_mixins/agentic/moltis/README.md#optional-shared-matrix-room) for exact option and secret names. Do not grant the bots server administrator rights or use the human administrator token for Moltis.

## Clients and acceptance checks

Use FluffyChat on the Linux desktop. The user handles installation on the phone. Enter `https://matrix.wimpys.world:8443` as the homeserver on both clients. Do not assume automatic server discovery.

After deployment approval, the operator must check:

- The desktop and phone connect through the Tailnet with a valid certificate.
- The Matrix endpoint is unreachable off the Tailnet.
- Public requests for the HTTP hostname return `404`, not a Matrix redirect.
- Existing public sites on port `443` still work.
- Public registration and federation remain unavailable.
- The human account is the only room member with invitation rights.
- Each bot joins the intended room but rejects an invitation to another room.
- One explicit mention produces one peer response.
- Matrix direct messages cannot start operator work, and Telegram direct messages still work.

Mention checks accept `@room` and cross-bot mentions. They do not guarantee loop prevention. Keep hand-offs under human control and avoid automatic peer prompts.

No automatic runtime checks, SSH tests, or account provisioning form part of preparation. Full Malak Caddy validation remains pending before activation.

## Backups and message privacy

Messages are unencrypted at the Matrix room level. Tailnet access and HTTPS protect transport, not readable messages in the server database or backups. Do not put credentials or private operator instructions in the shared room.

Protect the Tuwunel database, configuration, and backups with restricted access and encrypted backup storage. Use a database-consistent backup procedure and test restoration in an isolated environment. Treat bot access tokens as secrets. Revoke and replace a token after exposure.

Before activation, obtain the remaining operator inputs and separate deployment approval. After deployment, complete the acceptance checks above.
