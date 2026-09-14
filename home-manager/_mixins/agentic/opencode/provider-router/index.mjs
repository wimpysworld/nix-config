const markerKey = "nix-config.opencode-provider-router.v1";

function data(result) {
  if (result.error || result.data === undefined) {
    throw new Error("Provider router: OpenCode lookup failed.");
  }
  return result.data;
}

function taskReferences(messages, sessionID) {
  return messages.flatMap(({ info, parts }) =>
    info.role === "assistant"
      ? parts
          .filter(
            (part) =>
              part.type === "tool" &&
              part.tool === "task" &&
              part.state.metadata?.sessionId === sessionID,
          )
          .map((part) => ({ info, part }))
      : [],
  );
}

function savedRoute(history, parentID, agent, references) {
  const saved = [];
  for (const { info, parts } of history) {
    for (const part of parts) {
      if (
        part.type !== "text" ||
        !Object.hasOwn(part.metadata ?? {}, markerKey)
      )
        continue;
      const marker = part.metadata[markerKey];
      if (!marker || typeof marker !== "object" || Array.isArray(marker)) {
        throw new Error("Provider router: invalid saved route.");
      }
      const origin = references.filter(
        ({ part: task }) => task.id === marker.taskID,
      );
      if (
        info.role !== "user" ||
        info.agent !== agent ||
        marker.agent !== agent ||
        marker.parentID !== parentID ||
        marker.providerID !== info.model.providerID ||
        marker.modelID !== info.model.modelID ||
        origin.length !== 1 ||
        origin[0].info.providerID !== marker.providerID ||
        origin[0].part.state.input.subagent_type !== agent
      ) {
        throw new Error("Provider router: invalid saved route.");
      }
      saved.push(marker);
    }
  }
  if (
    saved.some(
      (route) =>
        route.providerID !== saved[0].providerID ||
        route.modelID !== saved[0].modelID ||
        route.taskID !== saved[0].taskID,
    )
  ) {
    throw new Error("Provider router: conflicting saved routes.");
  }
  return saved[0];
}

async function validateModel(client, route) {
  const catalogue = data(await client.provider.list());
  const provider = catalogue.all.find((item) => item.id === route.providerID);
  if (
    !catalogue.connected.includes(route.providerID) ||
    !provider ||
    !Object.hasOwn(provider.models, route.modelID) ||
    provider.models[route.modelID].id !== route.modelID
  ) {
    throw new Error(
      `Provider router: unavailable exact model ${route.providerID}/${route.modelID}.`,
    );
  }
}

export default function createRouter(client, routes) {
  const entering = new Set();
  const active = new Map();

  return {
    "chat.message": async (input, output) => {
      const sessionID = input.sessionID;
      const child = data(await client.session.get({ path: { id: sessionID } }));
      if (!child.parentID) return;
      const parent = data(
        await client.session.get({ path: { id: child.parentID } }),
      );
      if (parent.parentID) return;
      if (entering.has(sessionID)) {
        throw new Error(
          "Provider router: concurrent child prompts are unsupported.",
        );
      }
      // Acquire before history lookups, including the gap before message persistence.
      entering.add(sessionID);
      try {
        const references = taskReferences(
          data(await client.session.messages({ path: { id: parent.id } })),
          sessionID,
        );
        const previous = active.get(sessionID);
        if (previous) {
          if (
            references.some(
              ({ part }) =>
                part.id === previous && part.state.status === "running",
            )
          ) {
            throw new Error(
              "Provider router: concurrent child prompts are unsupported.",
            );
          }
          active.delete(sessionID);
        }
        const running = references.filter(
          ({ part }) => part.state.status === "running",
        );
        if (running.length !== 1) return;
        const { info, part: task } = running[0];
        const agent = output.message.agent;
        if (task.state.input.subagent_type !== agent) return;
        const history = data(
          await client.session.messages({ path: { id: sessionID } }),
        );
        if (
          history.some(({ parts }) =>
            parts.some(
              (part) =>
                part.type === "text" &&
                part.metadata?.[markerKey]?.promptTaskID === task.id,
            ),
          )
        ) {
          throw new Error(
            "Provider router: concurrent child prompts are unsupported.",
          );
        }
        let route = savedRoute(history, parent.id, agent, references);
        if (!route) {
          // Never retrofit a route onto an existing native child.
          if (history.length !== 0) return;
          const modelID = routes[agent]?.[info.providerID];
          if (modelID === undefined) return;
          if (typeof modelID !== "string" || !/^[^\s/]+$/.test(modelID)) {
            throw new Error("Provider router: invalid exact model route.");
          }
          route = {
            parentID: parent.id,
            taskID: task.id,
            agent,
            providerID: info.providerID,
            modelID,
          };
        }
        const text = output.parts.find((part) => part.type === "text");
        if (!text) return;
        await validateModel(client, route);
        // OpenCode 1.18.30 persists these live objects after chat.message returns.
        Object.assign(output.message.model, {
          providerID: route.providerID,
          modelID: route.modelID,
        });
        text.metadata = {
          ...text.metadata,
          [markerKey]: { ...route, promptTaskID: task.id },
        };
        active.set(sessionID, task.id);
      } finally {
        entering.delete(sessionID);
      }
    },
    event: async ({ event }) => {
      if (event.type !== "message.part.updated") return;
      const part = event.properties.part;
      if (
        part.type !== "tool" ||
        part.tool !== "task" ||
        part.state.status === "running"
      )
        return;
      const sessionID = part.state.metadata?.sessionId;
      if (sessionID && active.get(sessionID) === part.id)
        active.delete(sessionID);
    },
  };
}
