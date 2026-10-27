const markerKey = "nix-config.opencode-provider-router.v2";

function running(messages) {
  return messages.flatMap((message) =>
    message.type === "assistant"
      ? message.content.filter((part) =>
          part.type === "tool" && part.name === "subagent" && part.state.status === "running",
        ).map((part) => ({ message, part }))
      : [],
  );
}

// OpenCode publishes the child session ID to the running subagent part after
// the child prompt starts. Until then, match the part by the fields that it
// shares with the child session and the child's prompt text.
function launches(parts, child, text) {
  return parts.filter(({ part }) => {
    const input = part.state.input ?? {};
    if (part.state.metadata?.sessionID !== undefined || input.agent !== child.agent) return false;
    if (input.sessionID !== undefined) return input.sessionID === child.id;
    return (input.description === undefined || child.title === undefined || input.description === child.title) &&
      (typeof input.prompt !== "string" || typeof text !== "string" || text.endsWith(input.prompt));
  });
}

// V2 plugin client methods resolve to the bare value. Older clients wrapped it
// as `{ data }`, so accept both forms.
function unwrap(result) {
  return result && typeof result === "object" && !Array.isArray(result) && "data" in result ? result.data : result;
}

// A route error names a route that the router must not use. Each kind maps to
// the clause that the session notice shows to the user.
const clauses = {
  unavailable: (agent, label) => `the route for ${agent} (${label}) is not available`,
  invalidModel: (agent, label) => `the route for ${agent} (${label}) names an invalid model`,
  invalidVariant: (agent, label) => `the route for ${agent} (${label}) names an invalid variant`,
  invalidSaved: (agent) => `the saved route for ${agent} is not valid`,
  ambiguous: (agent) => `${agent} has more than one active invocation with a saved route`,
  launches: (agent) => `routing for ${agent} is ambiguous: several subagent launches are running at once`,
  concurrent: (agent) => `${agent} received concurrent prompts for one invocation`,
};

class RouteError extends Error {
  constructor(message, kind, label) {
    super(message);
    this.kind = kind;
    this.label = label;
  }
}

function label(route) {
  return `${route.providerID}/${String(route.id)}${route.variant === undefined ? "" : ` variant ${route.variant}`}`;
}

function exactModel(model) {
  if (!model || typeof model.providerID !== "string" || typeof model.id !== "string") return undefined;
  return { providerID: model.providerID, id: model.id,
    ...(typeof model.variant === "string" ? { variant: model.variant } : {}) };
}

function list(value, name) {
  if (!Array.isArray(value)) throw new Error(`Provider router: unexpected ${name} result.`);
  return value;
}

async function validateModel(ctx, route) {
  const models = list(unwrap(await ctx.model.list({ location: ctx.location })), "model list");
  const model = models.find((item) => item.providerID === route.providerID && item.id === route.id);
  if (!model || model.disabled) {
    throw new RouteError(`Provider router: unavailable exact model ${route.providerID}/${route.id}.`,
      "unavailable", label(route));
  }
  if (route.variant !== undefined && !model.variants.some((item) => item.id === route.variant)) {
    throw new RouteError(`Provider router: unavailable variant ${route.variant}.`, "unavailable", label(route));
  }
}

export default async function createRouter(ctx, routes, variants = {}) {
  const entering = new Set();
  const noticed = new Set();
  // In V2 a rejected session hook fails the model request, so the hook never
  // rejects. An invalid route runs the child on the parent session's model,
  // and any other error keeps the native model.
  await ctx.session.hook("prompt", async (event) => {
    const seen = {};
    try {
      await routePrompt(event, seen);
    } catch (error) {
      console.error("Provider Router: prompt hook failed.", error);
      try {
        await recover(event.sessionID, seen, error);
      } catch (cause) {
        console.error("Provider Router: fallback failed.", cause);
      }
    }
  });
  async function parentModel(parent) {
    const model = exactModel(parent.model);
    if (model) return model;
    try {
      const messages = unwrap(await ctx.session.context({ sessionID: parent.id }));
      return Array.isArray(messages)
        ? exactModel(messages.findLast((item) => item?.type === "assistant" && exactModel(item.model))?.model)
        : undefined;
    } catch {
      return undefined;
    }
  }
  async function recover(sessionID, { child, parent, taskID }, error) {
    if (!child || !parent) return;
    const agent = child.agent;
    const native = exactModel(child.model);
    let clause = `routing for ${agent} failed with an internal error`;
    let model;
    if (error instanceof RouteError) {
      clause = clauses[error.kind](agent, error.label);
      model = await parentModel(parent);
      if (model) await ctx.session.switchModel({ sessionID, model });
    }
    const key = `${sessionID}/${taskID ?? ""}/${error instanceof RouteError ? error.kind : "internal"}`;
    if (noticed.has(key)) return;
    noticed.add(key);
    const ran = model ? `${agent} ran on ${label(model)}`
      : `${agent} ran on its native model${native ? ` ${label(native)}` : ""}`;
    // The parent session is busy with the subagent call, so post without
    // waiting for the notice to land.
    Promise.resolve()
      .then(() => ctx.session.synthetic({ sessionID: parent.id, text: `Provider Router: ${clause}, so ${ran}.`,
        description: "Provider Router", resume: false }))
      .catch((cause) => console.error("Provider Router: notice failed.", cause));
  }
  async function routePrompt(event, seen) {
    const sessionID = event.sessionID;
    const child = unwrap(await ctx.session.get({ sessionID }));
    if (!child?.parentID) return;
    const parent = unwrap(await ctx.session.get({ sessionID: child.parentID }));
    if (!parent || parent.parentID) return;
    Object.assign(seen, { child, parent });
    if (entering.has(sessionID)) {
      throw new RouteError("Provider router: concurrent child prompts are unsupported.", "concurrent");
    }
    entering.add(sessionID);
    try {
      const messages = list(unwrap(await ctx.session.context({ sessionID: parent.id })), "session context");
      const parts = running(messages);
      let matches = parts.filter(({ part }) => part.state.metadata?.sessionID === sessionID);
      const key = `${markerKey}/${sessionID}`;
      const saved = unwrap(await ctx.storage.get(key));
      if (saved !== undefined && (!saved || typeof saved !== "object" || Array.isArray(saved))) {
        throw new RouteError("Provider router: invalid saved route.", "invalidSaved");
      }
      const agent = child.agent;
      if (matches.length === 0) {
        matches = launches(parts, child, event.prompt?.text);
        if (matches.length > 1 && (saved !== undefined || matches.some(({ message, part }) =>
          !part.state.input.model && routes[agent]?.[message.model?.providerID] !== undefined))) {
          throw new RouteError("Provider router: ambiguous concurrent subagent launches.", "launches");
        }
      }
      if (matches.length !== 1) {
        if (saved !== undefined) throw new RouteError("Provider router: ambiguous saved-route invocation.", "ambiguous");
        return;
      }
      const { message, part } = matches[0];
      seen.taskID = part.id;
      if (part.state.input.agent !== agent) return;
      // An explicit native model override belongs to the caller, not the router.
      if (part.state.input.model) return;
      let route = saved;
      if (route) {
        if (route.parentID !== parent.id || route.agent !== agent ||
            typeof route.providerID !== "string" || typeof route.id !== "string" ||
            typeof route.taskID !== "string" || typeof route.promptTaskID !== "string" ||
            (route.variant !== undefined && typeof route.variant !== "string")) {
          throw new RouteError("Provider router: invalid saved route.", "invalidSaved");
        }
        if (route.promptTaskID === part.id) {
          throw new RouteError("Provider router: concurrent child prompts are unsupported.", "concurrent");
        }
      } else {
        const history = list(unwrap(await ctx.session.context({ sessionID })), "session context");
        if (history.length !== 0) return;
        const providerID = message.model.providerID;
        const id = routes[agent]?.[providerID];
        if (id === undefined) return;
        if (typeof id !== "string" || !/^[^\s/]+$/.test(id)) {
          throw new RouteError("Provider router: invalid exact model route.", "invalidModel", label({ providerID, id }));
        }
        // OpenCode names the absence of an explicit variant "default".
        const native = child.model?.variant === "default" ? undefined : child.model?.variant;
        const variant = variants[agent]?.[providerID] ?? native;
        if (variant !== undefined && (typeof variant !== "string" || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(variant))) {
          throw new RouteError("Provider router: invalid variant route.", "invalidVariant",
            label({ providerID, id, variant: String(variant) }));
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
  }
}
