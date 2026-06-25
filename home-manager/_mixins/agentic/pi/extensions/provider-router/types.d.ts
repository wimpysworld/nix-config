declare module "node:fs" {
  export function readFileSync(path: string, encoding: "utf-8"): string;
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
    };
  }

  export interface ExtensionAPI {
    on(event: "session_start" | "resources_discover", handler: (...args: unknown[]) => void): void;
    on(event: "tool_call", handler: (event: unknown, ctx: ExtensionContext) => void): void;
  }

  export function isToolCallEventType<TName extends string, TInput extends Record<string, unknown>>(
    toolName: TName,
    event: unknown,
  ): event is { input: TInput };
}
