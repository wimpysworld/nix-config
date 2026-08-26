import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

// Bridge pi-service-tier's fast-mode indicator into Pi's extension status API
// so pi-footer can display it. pi-service-tier publishes its state only as a
// pi-fancy-footer widget event ("⚡" when a provider service tier is active,
// empty otherwise). Those events travel over Pi's shared event bus, so this
// extension maps the widget text to an always-visible "Fast on"/"Fast off"
// status key that a pi-footer external-status widget reads, matching the
// Codex and Claude Code status lines.
const STATUS_KEY = "noughty-service-tier:status";
const WIDGET_ID = "pi-service-tier.service-tier";
const FANCY_FOOTER_PROTOCOL = 1;
const WIDGET_EVENT = "pi-fancy-footer:widget";
const READY_EVENT = "pi-fancy-footer:ready";

interface WidgetEvent {
	protocol?: unknown;
	type?: unknown;
	id?: unknown;
	widget?: {
		id?: unknown;
		content?: {
			text?: unknown;
		};
	};
}

export default function registerServiceTierStatus(pi: ExtensionAPI): void {
	let ctx: ExtensionContext | undefined;
	let active = false;

	function publish(): void {
		ctx?.ui.setStatus(STATUS_KEY, active ? "Fast on" : "Fast off");
	}

	pi.events.on(WIDGET_EVENT, (message) => {
		if (typeof message !== "object" || message === null) return;
		const event = message as WidgetEvent;
		if (event.protocol !== FANCY_FOOTER_PROTOCOL) return;

		if (event.type === "remove" && event.id === WIDGET_ID) {
			active = false;
			publish();
			return;
		}

		if (event.type !== "upsert" || event.widget?.id !== WIDGET_ID) return;
		const text = event.widget?.content?.text;
		active = typeof text === "string" && text.length > 0;
		publish();
	});

	pi.on("session_start", (_event, context) => {
		ctx = context;
		publish();
		// pi-service-tier re-publishes its widget on this handshake, which
		// covers the load order where it initialised before this bridge.
		pi.events.emit(READY_EVENT, { protocol: FANCY_FOOTER_PROTOCOL });
	});

	pi.on("session_shutdown", () => {
		ctx?.ui.setStatus(STATUS_KEY, undefined);
		ctx = undefined;
	});
}
