import { type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

interface HeaderComponent {
	dispose(): void;
	stopAnimation(): void;
}

interface LogoDefinition {
	id: string;
	lines: string[];
}

interface LogoAnimation {
	id: string;
}

interface HeaderModule {
	createHeaderComponent(options: {
		tui: unknown;
		theme: unknown;
		logoLines: string[];
		animation: LogoAnimation;
	}): HeaderComponent;
}

interface LogoDemoModule {
	getCompatibleAnimations(logo: LogoDefinition): LogoAnimation[];
	randomItem<T>(items: readonly T[]): T;
	STATIC_ANIMATION?: LogoAnimation;
}

interface LogosModule {
	logos: LogoDefinition[];
}

const KEPT_LOGOS = new Set([
	"logo-001",
	"logo-002",
	"logo-003",
	"logo-004",
	"logo-005",
	"logo-006",
	"logo-007",
	"logo-008",
	"logo-009",
]);

function piLogoModuleUrl(relativePath: string): string {
	const agentDir = process.env.PI_AGENT_DIR ?? path.join(os.homedir(), ".pi", "agent");
	return pathToFileURL(path.join(agentDir, "npm", "node_modules", "pi-logo", "src", relativePath)).href;
}

export default async function registerHeaderExtension(pi: ExtensionAPI) {
	const { createHeaderComponent } = (await import(piLogoModuleUrl("header.ts"))) as HeaderModule;
	const { getCompatibleAnimations, randomItem, STATIC_ANIMATION } = (await import(
		piLogoModuleUrl("logo-demo.ts")
	)) as LogoDemoModule;
	const { logos } = (await import(piLogoModuleUrl("logos/logos.ts"))) as LogosModule;
	const filteredLogos = logos.filter((logo) => KEPT_LOGOS.has(logo.id));

	let activeHeader: HeaderComponent | undefined;

	pi.on("session_shutdown", async () => {
		activeHeader?.dispose();
		activeHeader = undefined;
	});

	pi.on("session_start", async (event, ctx) => {
		if (!ctx.hasUI) return;

		activeHeader?.dispose();
		activeHeader = undefined;

		const logo = randomItem(filteredLogos);
		const shouldAnimate = event.reason === "startup" || event.reason === "new";
		const animation = shouldAnimate ? randomItem(getCompatibleAnimations(logo)) : STATIC_ANIMATION;
		let header: HeaderComponent | undefined;

		if (!animation) return;

		ctx.ui.setHeader((tui, theme) => {
			header = createHeaderComponent({
				tui,
				theme,
				logoLines: logo.lines,
				animation,
			});
			activeHeader = header;

			return header;
		});

		ctx.ui.onTerminalInput((data) => {
			if (matchesKey(data, "enter")) {
				header?.stopAnimation();
			}

			return undefined;
		});
	});
}
