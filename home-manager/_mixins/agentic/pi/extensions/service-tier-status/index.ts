import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "noughty-service-tier:status";
const FAST_BETA = "fast-mode-2026-02-01";
// Pi's catalogue has no speed capability field. Keep these exact IDs in step
// with the provider references in ../../README.md, not model-name prefixes.
const OPENAI_FAST_MODELS = new Set([
	"gpt-6-astra",
	"gpt-5.6-sol",
	"gpt-5.6-terra",
	"gpt-5.6-luna",
]);
const ANTHROPIC_FAST_MODELS = new Set(["claude-opus-5", "claude-opus-4-8"]);
type Adapter = "openai" | "openai-codex" | "anthropic";

function adapterFor(model: ExtensionContext["model"]): Adapter | undefined {
	if (!model) return;
	if (
		model.provider === "openai" &&
		model.api === "openai-responses" &&
		model.baseUrl === "https://api.openai.com/v1"
	)
		return "openai";
	if (
		model.provider === "openai-codex" &&
		model.api === "openai-codex-responses" &&
		model.baseUrl === "https://chatgpt.com/backend-api"
	)
		return "openai-codex";
	if (
		model.provider === "anthropic" &&
		model.api === "anthropic-messages" &&
		model.baseUrl === "https://api.anthropic.com"
	)
		return "anthropic";
}

function supportsFast(
	ctx: ExtensionContext,
	adapter: Adapter | undefined,
): boolean {
	const model = ctx.model;
	if (!model || !adapter || !ctx.modelRegistry.find(model.provider, model.id))
		return false;
	return (
		adapter === "anthropic" ? ANTHROPIC_FAST_MODELS : OPENAI_FAST_MODELS
	).has(model.id);
}

export default function registerServiceTierStatus(pi: ExtensionAPI): void {
	let fast = false;
	let modelKey = "";

	function sync(ctx: ExtensionContext): Adapter | undefined {
		const model = ctx.model;
		const key = JSON.stringify([
			model?.provider,
			model?.id,
			model?.api,
			model?.baseUrl,
		]);
		if (key !== modelKey) fast = false;
		modelKey = key;
		const adapter = adapterFor(model);
		if (!supportsFast(ctx, adapter)) fast = false;
		return adapter;
	}

	function status(ctx: ExtensionContext): string {
		const adapter = sync(ctx);
		if (!adapter) return "Fast unavailable; standard not enforced";
		const tier =
			adapter === "anthropic"
				? "standard_only"
				: adapter === "openai"
					? "default"
					: "omitted";
		const request = fast
			? adapter === "anthropic"
				? "fast; tier standard_only"
				: "priority"
			: `standard; tier ${tier}`;
		const availability = supportsFast(ctx, adapter) ? "" : "; Fast unavailable";
		return `Requested ${request}${availability}`;
	}

	function publish(ctx: ExtensionContext): string {
		const text = status(ctx);
		if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, text);
		return text;
	}

	pi.registerCommand("fast", {
		description:
			"Request Fast for this session: /fast on|off|status (default off)",
		handler: async (args, ctx) => {
			const command = args.trim();
			if (!["", "status", "on", "off"].includes(command)) {
				if (ctx.hasUI)
					ctx.ui.notify("Usage: /fast on|off|status. No change.", "warning");
				return;
			}
			// Apply changes between requests so Anthropic headers and body agree.
			if (command === "on" || command === "off") await ctx.waitForIdle();
			const adapter = sync(ctx);
			if (command === "on") fast = supportsFast(ctx, adapter);
			if (command === "off") fast = false;
			const text = publish(ctx);
			if (ctx.hasUI) ctx.ui.notify(text, "info");
		},
	});

	pi.on("session_start", (_event, ctx) => {
		fast = false;
		publish(ctx);
	});
	pi.on("model_select", (_event, ctx) => {
		fast = false;
		publish(ctx);
	});
	pi.on("session_shutdown", (_event, ctx) => {
		fast = false;
		if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, undefined);
	});

	pi.on("before_provider_headers", (event, ctx) => {
		if (sync(ctx) !== "anthropic") return;
		const tokens: string[] = [];
		for (const key of Object.keys(event.headers)) {
			if (key.toLowerCase() !== "anthropic-beta") continue;
			const value = event.headers[key];
			if (typeof value === "string")
				tokens.push(
					...value
						.split(",")
						.map((token) => token.trim())
						.filter((token) => token && token !== FAST_BETA),
				);
			event.headers[key] = null;
		}
		if (fast) tokens.push(FAST_BETA);
		// Apply the canonical value after removals with other letter cases.
		delete event.headers["anthropic-beta"];
		event.headers["anthropic-beta"] = tokens.length
			? [...new Set(tokens)].join(",")
			: null;
	});

	pi.on("before_provider_request", (event, ctx) => {
		const adapter = sync(ctx);
		publish(ctx);
		if (
			!adapter ||
			!event.payload ||
			typeof event.payload !== "object" ||
			Array.isArray(event.payload)
		)
			return;
		const payload = { ...event.payload } as Record<string, unknown>;
		if (adapter === "anthropic") {
			payload.service_tier = "standard_only";
			delete payload.speed;
			if (fast) payload.speed = "fast";
		} else if (adapter === "openai-codex") {
			delete payload.service_tier;
			if (fast) payload.service_tier = "priority";
		} else {
			payload.service_tier = fast ? "priority" : "default";
		}
		return payload;
	});
}
