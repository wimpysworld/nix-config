// Preload hook that registers missing model context windows in LibreChat 0.8.8,
// strips any stale 1024-token floor cached in conversation or preset payloads,
// enables stateful code sessions on ephemeral agents with execute_code,
// and rewrites the code-interpreter tool network-access description to match
// the firewall-filtered internet egress policy.
// Gemini 4 Neon defaults to high thinking, Carbon and Hydrogen to medium.
'use strict';

const Module = require('module');
const originalLoad = Module._load;

let patchedDataProvider = false;
const auxiliaryInitializers = new WeakMap();
const patchedToolModules = new WeakMap();
const patchedApiModules = new WeakMap();

const NO_NETWORK_LINE = '- No network access available.';
const SANDBOX_ENVIRONMENT_LINES = [
  '- Public internet access is available. Localhost, private LAN, link-local, and Tailscale addresses are blocked by firewall.',
  '- Invoked skill assets and scripts are mounted under /mnt/data/skills/<skillName>/.',
  '- Files in /mnt/data (including extensionless files and dotfiles) persist across calls, while /tmp clears between calls and /var/cache/sandbox holds per-user caches.',
].join('\n');

function enableStatefulCodeSessions(agent) {
  if (
    agent &&
    typeof agent === 'object' &&
    Array.isArray(agent.tools) &&
    agent.tools.includes('execute_code') &&
    agent.stateful_code_sessions === undefined
  ) {
    return {
      ...agent,
      stateful_code_sessions: true,
    };
  }
  return agent;
}

function wrapMaybeAsyncResult(result, transform) {
  if (result && typeof result.then === 'function') {
    return result.then(transform);
  }
  return transform(result);
}

function isEphemeralAgentId(agentId) {
  return typeof agentId !== 'string' || !agentId.startsWith('agent_');
}

function patchApiModule(exported) {
  if (patchedApiModules.has(exported)) {
    return patchedApiModules.get(exported);
  }

  const extraModels = {
    'gemini-4': 1048576,
    'gemini-4-neon': 1048576,
    'gemini-4-carbon': 1048576,
    'gemini-4-hydrogen': 1048576,
    'gpt-6-terra': 1050000,
    'gpt-6.1-terra': 1050000,
  };
  for (const bucket of ['openAI', 'agents', 'custom', 'google', 'azureOpenAI']) {
    if (exported.maxTokensMap[bucket] && typeof exported.maxTokensMap[bucket] === 'object') {
      Object.assign(exported.maxTokensMap[bucket], extraModels);
    }
  }
  if (typeof exported.providerConfigMap?.google === 'function') {
    const originalInitializeGoogle = exported.providerConfigMap.google;
    exported.providerConfigMap.google = function initializeGoogleWithDefaults(params, ...args) {
      const modelParameters = params?.model_parameters;
      if (
        /^gemini-4-(neon|carbon|hydrogen)$/.test(modelParameters?.model ?? '') &&
        modelParameters.thinking !== false &&
        (modelParameters.thinkingLevel == null || modelParameters.thinkingLevel === '')
      ) {
        return originalInitializeGoogle.call(
          this,
          {
            ...params,
            model_parameters: {
              ...modelParameters,
              thinkingLevel: modelParameters.model === 'gemini-4-neon' ? 'high' : 'medium',
            },
          },
          ...args,
        );
      }
      return originalInitializeGoogle.apply(this, arguments);
    };
  }

  const overrides = Object.create(null);

  if (typeof exported.loadEphemeralAgent === 'function') {
    const originalLoadEphemeralAgent = exported.loadEphemeralAgent;
    overrides.loadEphemeralAgent = function wrappedLoadEphemeralAgent() {
      return wrapMaybeAsyncResult(
        originalLoadEphemeralAgent.apply(this, arguments),
        enableStatefulCodeSessions,
      );
    };
  }

  if (typeof exported.loadAgent === 'function') {
    const originalLoadAgent = exported.loadAgent;
    overrides.loadAgent = function wrappedLoadAgent(params) {
      const result = originalLoadAgent.apply(this, arguments);
      if (params && typeof params === 'object' && isEphemeralAgentId(params.agent_id)) {
        return wrapMaybeAsyncResult(result, enableStatefulCodeSessions);
      }
      return result;
    };
  }

  let needsProxy = false;
  for (const [key, wrappedFn] of Object.entries(overrides)) {
    const desc = Object.getOwnPropertyDescriptor(exported, key);
    if (desc && desc.writable) {
      exported[key] = wrappedFn;
    } else if (desc && desc.configurable) {
      Object.defineProperty(exported, key, {
        value: wrappedFn,
        enumerable: desc.enumerable,
        writable: true,
        configurable: true,
      });
    } else {
      needsProxy = true;
    }
  }

  const result = needsProxy
    ? new Proxy(exported, {
        get(target, prop, receiver) {
          if (typeof prop === 'string' && prop in overrides) {
            return overrides[prop];
          }
          return Reflect.get(target, prop, receiver);
        },
      })
    : exported;

  patchedApiModules.set(exported, result);
  return result;
}

function rewriteNetworkDescription(value) {
  if (typeof value !== 'string') {
    return value;
  }
  return value.replaceAll(NO_NETWORK_LINE, SANDBOX_ENVIRONMENT_LINES);
}

function rewriteToolDescription(tool) {
  if (tool && typeof tool === 'object' && typeof tool.description === 'string') {
    const rewritten = rewriteNetworkDescription(tool.description);
    if (rewritten !== tool.description) {
      try {
        tool.description = rewritten;
      } catch {
        // Leave non-writable tool descriptions untouched.
      }
    }
  }
  return tool;
}

function isExecutorToolModule(request, parent) {
  if (typeof request !== 'string') {
    return false;
  }
  if (
    (request === './tools/BashExecutor.cjs' || request === './tools/CodeExecutor.cjs') &&
    typeof parent?.filename === 'string' &&
    parent.filename.includes('/@librechat/agents/dist/cjs/')
  ) {
    return true;
  }
  return (
    request.endsWith('/@librechat/agents/dist/cjs/tools/BashExecutor.cjs') ||
    request.endsWith('/@librechat/agents/dist/cjs/tools/CodeExecutor.cjs')
  );
}

function wrapExecutorToolModule(exported) {
  if (patchedToolModules.has(exported)) {
    return patchedToolModules.get(exported);
  }
  const wrapped = { ...exported };
  for (const key of [
    'BashExecutionToolDescription',
    'StatefulBashExecutionToolDescription',
    'CodeExecutionToolDescription',
    'StatefulCodeExecutionToolDescription',
  ]) {
    if (typeof exported[key] === 'string') {
      wrapped[key] = rewriteNetworkDescription(exported[key]);
    }
  }
  for (const key of ['BashExecutionToolDefinition', 'CodeExecutionToolDefinition']) {
    const def = exported[key];
    if (def && typeof def === 'object' && typeof def.description === 'string') {
      wrapped[key] = {
        ...def,
        description: rewriteNetworkDescription(def.description),
      };
    }
  }
  for (const key of ['buildBashExecutionToolDescription', 'buildCodeExecutionToolDescription']) {
    if (typeof exported[key] === 'function') {
      const originalBuilder = exported[key];
      wrapped[key] = function wrappedBuildToolDescription() {
        return rewriteNetworkDescription(originalBuilder.apply(this, arguments));
      };
    }
  }
  for (const key of ['createBashExecutionTool', 'createCodeExecutionTool']) {
    if (typeof exported[key] === 'function') {
      const originalFactory = exported[key];
      wrapped[key] = function wrappedCreateExecutionTool() {
        const result = originalFactory.apply(this, arguments);
        if (result && typeof result.then === 'function') {
          return result.then(rewriteToolDescription);
        }
        return rewriteToolDescription(result);
      };
    }
  }
  patchedToolModules.set(exported, wrapped);
  return wrapped;
}

Module._load = function patchedModuleLoad(request, parent, isMain) {
  const exported = originalLoad.apply(this, arguments);

  if (exported && typeof exported === 'object' && isExecutorToolModule(request, parent)) {
    return wrapExecutorToolModule(exported);
  }

  // Titles discard thinking options, while summaries inherit the main model's options.
  if (
    ((request === './llm/init.cjs' &&
      parent?.filename?.endsWith('/@librechat/agents/dist/cjs/run.cjs')) ||
      (request === '../llm/init.cjs' &&
        parent?.filename?.endsWith('/@librechat/agents/dist/cjs/summarization/node.cjs'))) &&
    typeof exported?.initializeModel === 'function'
  ) {
    if (!auxiliaryInitializers.has(exported)) {
      const originalInitializeModel = exported.initializeModel;
      auxiliaryInitializers.set(exported, {
        ...exported,
        initializeModel(params, ...args) {
          const options = params?.clientOptions;
          if (
            params?.provider === 'google' &&
            options?.model === 'gemini-4-hydrogen' &&
            options.thinking !== false &&
            options.thinkingConfig?.includeThoughts !== false
          ) {
            const { thinkingLevel, ...clientOptions } = options;
            return originalInitializeModel.call(
              this,
              {
                ...params,
                clientOptions: {
                  ...clientOptions,
                  thinkingConfig: {
                    ...options.thinkingConfig,
                    thinkingLevel:
                      thinkingLevel?.toUpperCase() || options.thinkingConfig?.thinkingLevel || 'MEDIUM',
                  },
                },
              },
              ...args,
            );
          }
          return originalInitializeModel.apply(this, arguments);
        },
      });
    }
    return auxiliaryInitializers.get(exported);
  }

  if (
    !patchedDataProvider &&
    (request === 'librechat-data-provider' ||
      (typeof request === 'string' && request.endsWith('/packages/data-provider'))) &&
    exported &&
    typeof exported === 'object'
  ) {
    patchedDataProvider = true;
    if (exported.providerEndpointMap && typeof exported.providerEndpointMap === 'object') {
      exported.providerEndpointMap.google = 'google';
    }
    if (typeof exported.parseCompactConvo === 'function') {
      const origParseCompactConvo = exported.parseCompactConvo;
      exported.parseCompactConvo = function wrappedParseCompactConvo(params) {
        if (
          params &&
          params.conversation &&
          typeof params.conversation === 'object' &&
          Number(params.conversation.maxContextTokens) <= 1024
        ) {
          const cleanedConversation = { ...params.conversation };
          delete cleanedConversation.maxContextTokens;
          return origParseCompactConvo.call(this, {
            ...params,
            conversation: cleanedConversation,
          });
        }
        return origParseCompactConvo.apply(this, arguments);
      };
    }
  }

  if (
    (request === '@librechat/api' ||
      (typeof request === 'string' && request.endsWith('/packages/api'))) &&
    exported &&
    typeof exported === 'object' &&
    exported.maxTokensMap
  ) {
    return patchApiModule(exported);
  }

  return exported;
};
