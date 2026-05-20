import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "noughty-quota:usage";

interface RateWindow {
	label?: unknown;
	resetDescription?: unknown;
	usedPercent?: unknown;
}

interface UsageSnapshot {
	windows?: unknown;
}

interface SubCoreState {
	provider?: unknown;
	usage?: UsageSnapshot;
}

interface SubCorePayload {
	state?: SubCoreState;
}

function normaliseLabel(window: RateWindow): string {
	const label = typeof window.label === "string" ? window.label.trim() : "";
	const lower = label.toLowerCase();

	if (lower === "week" || lower === "7d" || lower === "seven day") return "weekly";
	if (lower === "day" || lower === "24h") return "daily";
	if (label.length > 0) return label;

	return typeof window.resetDescription === "string" ? window.resetDescription.trim() : "";
}

function formatWindow(window: RateWindow): string | undefined {
	const usedPercent = typeof window.usedPercent === "number" ? window.usedPercent : undefined;
	if (usedPercent === undefined || !Number.isFinite(usedPercent)) return undefined;

	const label = normaliseLabel(window);
	const remainingPercent = 100 - usedPercent;
	const percent = `${Math.max(0, Math.min(100, Math.round(remainingPercent)))}%`;
	return label.length > 0 ? `${label} ${percent}` : percent;
}

function toWindows(value: unknown): RateWindow[] {
	if (!Array.isArray(value)) return [];
	return value.filter((window): window is RateWindow => typeof window === "object" && window !== null);
}

function formatUsage(provider: string | undefined, usage: UsageSnapshot | undefined): string | undefined {
	const windows = toWindows(usage?.windows);
	const parts = windows
		.map((window) => ({
			label: normaliseLabel(window),
			text: formatWindow(window),
		}))
		.filter((part): part is { label: string; text: string } => part.text !== undefined);

	const hasWeeklyWindow = parts.some((part) => part.label === "weekly");
	const hasAnthropicFiveHourWindow = provider === "anthropic" && parts.some((part) => part.label === "5h");

	if (hasAnthropicFiveHourWindow && !hasWeeklyWindow) {
		parts.splice(1, 0, {
			label: "weekly",
			text: "weekly 100%",
		});
	}

	const visibleParts = parts.slice(0, 2).map((part) => part.text);
	return visibleParts.length > 0 ? visibleParts.join(" · ") : undefined;
}

export default function registerQuotaStatus(pi: ExtensionAPI): void {
	let ctx: ExtensionContext | undefined;
	let currentProvider: string | undefined;
	const lastStatusByProvider = new Map<string, string>();

	function publish(value: string | undefined): void {
		ctx?.ui.setStatus(STATUS_KEY, value);
	}

	function handleState(state: SubCoreState | undefined): void {
		const provider = typeof state?.provider === "string" ? state.provider : currentProvider;
		const status = formatUsage(provider, state?.usage);

		if (provider && status) {
			currentProvider = provider;
			lastStatusByProvider.set(provider, status);
			publish(status);
			return;
		}

		if (provider) {
			currentProvider = provider;
			publish(lastStatusByProvider.get(provider));
			return;
		}

		publish(undefined);
	}

	pi.events.on("sub-core:ready", (payload) => {
		handleState((payload as SubCorePayload).state);
	});

	pi.events.on("sub-core:update-current", (payload) => {
		handleState((payload as SubCorePayload).state);
	});

	pi.on("session_start", (_event, context) => {
		ctx = context;
		currentProvider = context.model?.provider;
		publish(currentProvider ? lastStatusByProvider.get(currentProvider) : undefined);
	});

	pi.on("model_select" as "session_start", (_event, context) => {
		ctx = context;
		currentProvider = context.model?.provider;
		publish(currentProvider ? lastStatusByProvider.get(currentProvider) : undefined);
	});

	pi.on("session_shutdown", () => {
		publish(undefined);
		ctx = undefined;
		currentProvider = undefined;
	});
}
