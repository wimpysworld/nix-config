// Preload hook that registers missing model context windows in LibreChat 0.8.8
// and strips any stale 1024-token floor cached in conversation or preset payloads.
// Gemini 4 Neon defaults to high thinking, Carbon and Hydrogen to medium.
'use strict';

const Module = require('module');
const originalLoad = Module._load;

let patchedDataProvider = false;
let patchedApi = false;
const auxiliaryInitializers = new WeakMap();

Module._load = function patchedModuleLoad(request, parent, isMain) {
  const exported = originalLoad.apply(this, arguments);

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
    !patchedApi &&
    (request === '@librechat/api' ||
      (typeof request === 'string' && request.endsWith('/packages/api'))) &&
    exported &&
    typeof exported === 'object' &&
    exported.maxTokensMap
  ) {
    patchedApi = true;
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
  }

  return exported;
};
