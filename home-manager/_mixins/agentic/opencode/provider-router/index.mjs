const markerKey = "nix-config.opencode-provider-router.v2";

function references(messages, sessionID) {
  return messages.flatMap((message) =>
    message.type === "assistant"
      ? message.content.filter((part) =>
          part.type === "tool" && part.name === "subagent" &&
          part.state.metadata?.sessionID === sessionID,
        ).map((part) => ({ message, part }))
      : [],
  );
}

async function validateModel(ctx, route) {
  const { data: models } = await ctx.model.list({ location: ctx.location });
  const model = models.find((item) => item.providerID === route.providerID && item.id === route.id);
  if (!model || model.disabled) {
    throw new Error(`Provider router: unavailable exact model ${route.providerID}/${route.id}.`);
  }
  if (route.variant !== undefined && !model.variants.some((item) => item.id === route.variant)) {
    throw new Error(`Provider router: unavailable variant ${route.variant}.`);
  }
}

export default async function createRouter(ctx, routes, variants = {}) {
  const entering = new Set();
  await ctx.session.hook("prompt", async (event) => {
    const sessionID = event.sessionID;
    const child = await ctx.session.get({ sessionID });
    if (!child.parentID) return;
    const parent = await ctx.session.get({ sessionID: child.parentID });
    if (parent.parentID) return;
    if (entering.has(sessionID)) throw new Error("Provider router: concurrent child prompts are unsupported.");
    entering.add(sessionID);
    try {
      const { data: messages } = await ctx.session.context({ sessionID: parent.id });
      const matches = references(messages, sessionID);
      const running = matches.filter(({ part }) => part.state.status === "running");
      const key = `${markerKey}/${sessionID}`;
      const saved = await ctx.storage.get(key);
      if (saved !== undefined && (!saved || typeof saved !== "object" || Array.isArray(saved))) {
        throw new Error("Provider router: invalid saved route.");
      }
      if (running.length !== 1) {
        if (saved !== undefined) throw new Error("Provider router: ambiguous saved-route invocation.");
        return;
      }
      const { message, part } = running[0];
      const agent = child.agent;
      if (part.state.input.agent !== agent) return;
      // An explicit native model override belongs to the caller, not the router.
      if (part.state.input.model) return;
      let route = saved;
      if (route) {
        if (route.parentID !== parent.id || route.agent !== agent ||
            typeof route.providerID !== "string" || typeof route.id !== "string" ||
            typeof route.taskID !== "string" || typeof route.promptTaskID !== "string" ||
            (route.variant !== undefined && typeof route.variant !== "string")) {
          throw new Error("Provider router: invalid saved route.");
        }
        if (route.promptTaskID === part.id) {
          throw new Error("Provider router: concurrent child prompts are unsupported.");
        }
      } else {
        const { data: history } = await ctx.session.context({ sessionID });
        if (history.length !== 0) return;
        const providerID = message.model.providerID;
        const id = routes[agent]?.[providerID];
        if (id === undefined) return;
        if (typeof id !== "string" || !/^[^\s/]+$/.test(id)) {
          throw new Error("Provider router: invalid exact model route.");
        }
        const variant = variants[agent]?.[providerID] ?? child.model?.variant;
        if (variant !== undefined && (typeof variant !== "string" || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(variant))) {
          throw new Error("Provider router: invalid variant route.");
        }
        route = { parentID: parent.id, taskID: part.id, agent, providerID, id,
          ...(variant === undefined ? {} : { variant }) };
      }
      await validateModel(ctx, route);
      const model = { providerID: route.providerID, id: route.id,
        ...(route.variant === undefined ? {} : { variant: route.variant }) };
      // Storage survives compaction. Reserve the invocation before admitting its prompt.
      await ctx.storage.set(key, { ...route, promptTaskID: part.id });
      await ctx.session.switchModel({ sessionID, model });
      event.metadata = { ...event.metadata, [markerKey]: { ...route, promptTaskID: part.id } };
    } finally {
      entering.delete(sessionID);
    }
  });
}
