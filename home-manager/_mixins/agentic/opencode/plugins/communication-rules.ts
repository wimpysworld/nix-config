import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const scannerPath = "@tripwireScanner@";
const rulesPath = "@tripwireRules@";
const correctionPromptPath = "@tripwireCorrectionPrompt@";
const FALLBACK_BLOCK = "Blocked. Revise this prose to follow the Communication Rules.";
const skippedFinishes = new Set(["tool-calls", "error", "unknown"]);

function readText(file: string): string {
  return readFileSync(file, "utf8").trimEnd();
}

function decide(event: string, payload: unknown) {
  try {
    const result = spawnSync(scannerPath, ["opencode", event], {
      input: JSON.stringify(payload), encoding: "utf8",
    });
    if (result.status === 0) {
      const decision = JSON.parse(result.stdout);
      if (decision && typeof decision === "object" && typeof decision.decision === "string") return decision;
    }
  } catch {
    // A scanner failure must not authorise a side effect.
  }
  throw new Error(FALLBACK_BLOCK);
}

function reminder() {
  const result = spawnSync(scannerPath, ["remind-brief", "opencode"], { encoding: "utf8" });
  return (result.status === 0 && result.stdout.trim()) || `Communication Rules:\n${readText(rulesPath)}`;
}

export default {
  id: "nix-config.communication-rules",
  async setup(ctx: any) {
    let observationFailed = false;
    let observationError: unknown;
    const controller = new AbortController();
    const checkObserver = () => {
      if (observationFailed) throw new Error("Communication Rules: event observation failed.", { cause: observationError });
    };
    const notify = async (sessionID: string, text: string) => {
      if (text) await ctx.session.synthetic({
        sessionID, text, description: "Communication Rules", resume: false,
      });
    };
    const inject = (event: any, sections: string[]) => {
      for (const text of sections) {
        if (text && !event.system.some((part: any) => part.type === "text" && part.text === text)) {
          event.system.push({ type: "text", text });
        }
      }
    };
    await ctx.session.hook("context", (event: any) => {
      checkObserver();
      const decision = decide("context", { sessionID: event.sessionID });
      if (decision.decision !== "pass") throw new Error(FALLBACK_BLOCK);
      inject(event, [
        ...(decision.inject_base_rules ? [reminder()] : []),
        ...(decision.append_correction ? [readText(correctionPromptPath)] : []),
      ]);
    });
    const auxiliaryContext = (event: any) => {
      checkObserver();
      inject(event, [reminder()]);
    };
    for (const name of ["compaction", "generate", "title"]) {
      await ctx.session.hook(name, auxiliaryContext);
    }
    await ctx.tool.hook("execute.before", async (event: any) => {
      checkObserver();
      const tool = (await ctx.tool.list()).find((item: any) => item.id === event.tool);
      const name = tool?.options?.namespace
        ? `mcp__${tool.options.namespace}__${tool.name}` : event.tool;
      const decision = decide("tool.execute.before", {
        event: "tool.execute.before", sessionID: event.sessionID, tool: name, args: event.input,
      });
      if (decision.decision === "pass") return;
      if (decision.decision === "yield" || decision.decision === "allow-revise") {
        await notify(event.sessionID, decision.notice);
        return;
      }
      throw new Error(decision.notice || decision.block_message || FALLBACK_BLOCK);
    });
    const observe = async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        // Tool-call, error and unknown steps carry no final prose. A provider
        // error must surface as an error, not as a rules breach.
        if (event.type !== "session.step.ended" || skippedFinishes.has(event.data.finish)) continue;
        const session = await ctx.session.get({ sessionID: event.data.sessionID });
        if (session.location.directory !== ctx.location.directory) continue;
        const { data } = await ctx.session.context({ sessionID: session.id });
        const message = data.find((item: any) => item.id === event.data.assistantMessageID);
        if (message?.type !== "assistant") throw new Error("Communication Rules: completed message is unavailable.");
        const text = message.content.filter((part: any) => part.type === "text")
          .map((part: any) => part.text).join("\n");
        // The scanner treats empty content as a breach, so skip steps with no text.
        if (!text.trim()) continue;
        const decision = decide("message.final", {
          event: "message.final", surface: "final", sessionID: session.id, message: { content: text },
        });
        if (!["pass", "block"].includes(decision.decision)) throw new Error(FALLBACK_BLOCK);
        await notify(session.id, decision.notice);
      }
      if (!controller.signal.aborted) throw new Error("Communication Rules: event stream closed.");
    };
    const observing = observe().catch((error) => {
      if (!controller.signal.aborted) {
        observationFailed = true;
        observationError = error;
      }
    });
    return async () => { controller.abort(); await observing; };
  },
};
