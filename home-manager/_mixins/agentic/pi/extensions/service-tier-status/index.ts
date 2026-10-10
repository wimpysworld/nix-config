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
const ANTHROPIC_FAST_MODELS = new Set(["claude-opus-5-5"]);
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
		if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, fast ? "Fast on" : "Fast off");
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
			// Apply changes between requests so Anthropic betas and body agree.
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
			// Edit Pi's computed betas in the body. An anthropic-beta header
			// replaces them all, including those that Pi's request fields need.
			const betas = (Array.isArray(payload.betas) ? payload.betas : []).filter(
				(token) => token !== FAST_BETA,
			);
			if (fast) betas.push(FAST_BETA);
			if (betas.length) payload.betas = betas;
			else delete payload.betas;
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
