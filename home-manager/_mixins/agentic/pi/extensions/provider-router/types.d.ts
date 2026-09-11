declare module "node:fs" {
	export function readFileSync(path: string, encoding: "utf-8"): string;
}

declare const process: { argv: string[] };

declare module "@earendil-works/pi-ai/compat" {
	export function getSupportedThinkingLevels(model: unknown): string[];
}

declare module "node:path" {
	export function join(...paths: string[]): string;
}

declare module "node:os" {
	export function homedir(): string;
}

declare module "@earendil-works/pi-coding-agent" {
	export interface ExtensionContext {
		model?: {
			id?: string;
			provider?: string;
		};
		modelRegistry: {
			find(provider: string, modelId: string): unknown;
			getAvailable(): { provider: string; id: string }[];
		};
		isIdle(): boolean;
		abort(): void;
		ui: { notify(message: string, level: string): void };
	}

	export interface ExtensionAPI {
		events: {
			emit(name: string, data: unknown): void;
			on(name: string, handler: (data: any) => void): () => void;
		};
		on(event: "session_shutdown", handler: () => void): void;
		setModel(model: any): Promise<boolean>;
		getThinkingLevel(): string;
		setThinkingLevel(level: string): void;
		on(
			event: "session_start" | "resources_discover",
			handler: (...args: unknown[]) => void,
		): void;
		on(
			event: "tool_call",
			handler: (event: unknown, ctx: ExtensionContext) => void,
		): void;
		on(
			event: "model_select",
			handler: (event: { source: string }) => void,
		): void;
		on(event: "agent_settled", handler: () => Promise<void>): void;
		on(
			event: "agent_start" | "before_agent_start",
			handler: (event: unknown, ctx: ExtensionContext) => Promise<void>,
		): void;
		on(
			event: "input",
			handler: (
				event: { text: string; streamingBehavior?: string },
				ctx: ExtensionContext,
			) => Promise<{ action: string }>,
		): void;
	}

	export function isToolCallEventType<
		TName extends string,
		TInput extends Record<string, unknown>,
	>(toolName: TName, event: unknown): event is { input: TInput };
}
