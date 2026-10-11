# Herdr Mobile Relay

[Herdr Mobile Relay](https://github.com/0cv/herdr-mobile-relay) lets a phone monitor and control Herdr agents. Every Home Manager configuration that installs Herdr runs the relay. Caddy on skrye and zannah serves the phone app over the tailnet.

## Phone app URLs

| App | URL |
| --- | --- |
| skrye (default) | `https://skrye.drongo-gamma.ts.net:8443` |
| zannah | `https://zannah.drongo-gamma.ts.net:8443` |

[lib/herdr-mobile-app.nix](../../../../lib/herdr-mobile-app.nix) holds one base URL for each host, and the default app. Caddy and the setup links both read that file. To move an app, change its URL there.

The app has its own port because browser storage is per origin, and that storage holds every relay key and device credential. Caddy refuses clients from outside the tailnet. The phone must have Tailscale connected each time it opens the app.

## Parts

| Part | Source |
| --- | --- |
| Package: Go relay, committed `web/` app, and Herdr plugin tree | [pkgs/herdr-mobile-relay/default.nix](../../../../pkgs/herdr-mobile-relay/default.nix) |
| Plugin link, relay service, `herdr-mobile-relay-link` | [home-manager/_mixins/terminal/herdr.nix](../../../../home-manager/_mixins/terminal/herdr.nix) |
| Caddy site on port 8443 | [default.nix](default.nix) |
| Fence read denial | [home-manager/_mixins/agentic/fence/default.nix](../../../../home-manager/_mixins/agentic/fence/default.nix) |
| Freshener job, with auto-merge off | [.github/freshener/herdr-mobile-relay.sh](../../../../.github/freshener/herdr-mobile-relay.sh) |

The relay runs outside Fence, as the `herdr-mobile-relay.service` systemd user service on Linux and as the `com.herdr-mobile-relay.service` launchd agent on Darwin. It uses the community WebRTC gateways, with port mapping off and App Deployment off.

The relay key, device store, and push keys are in `~/.config/herdr-mobile-relay/`. The service sets `HERDR_RELAY_ENV` to `~/.config/herdr-mobile-relay/relay.env`, and the relay keeps its runtime files in that directory. Fence denies reads of the directory to fenced agents.

## Pairing

1. Run `just switch-host` on skrye and on zannah.
2. Run `just switch-home` on each host, then log in again so that new shells and the Herdr server get `HERDR_RELAY_ENV` and `HERDR_PHONE_APP_URL`.
3. On the phone, connect Tailscale, open each app URL, and add it to the Home Screen.
4. On each host, run `herdr-mobile-relay-link skrye` and scan the QR code in the skrye app.
5. On each host, run `herdr-mobile-relay-link zannah` and scan the QR code in the zannah app.
6. Clear the terminal after each scan, because the link holds the relay key.

`herdr-mobile-relay-link` with no argument prints the skrye link. The Herdr action **Herdr Mobile Relay: Show Phone Setup QR** also prints the skrye link. Each link pairs one more phone and revokes no device.

Do not rotate the relay key as a routine step. A rotation disconnects every paired app on that host until it pairs again. Revoke unused devices in the app, because device credentials do not expire.

## Upgrades

The freshener opens a pull request for each upstream release and does not enable auto-merge. Review the upstream diff, including the `web/` bundle, before you merge. A new `go` line in `go.mod` can need a newer `buildGo*Module`.
