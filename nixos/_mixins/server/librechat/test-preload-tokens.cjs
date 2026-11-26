// The librechat-code-sandbox derivation runs these preload-hook tests during its build.
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const preloadPath = process.argv[2];
assert.ok(preloadPath, 'Expected path to preload-tokens.cjs as argv[2]');

// Install the Module._load hooks before loading fixture modules.
require(path.resolve(preloadPath));

const EXPECTED_NETWORK_LINE =
  '- Public internet access is available. Localhost, private LAN, link-local, and Tailscale addresses are blocked by firewall.';

function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
}

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'preload-tokens-test-'));

try {
  const agentsCjsDir = path.join(tmpDir, 'node_modules', '@librechat', 'agents', 'dist', 'cjs');
  const bashExecutorPath = path.join(agentsCjsDir, 'tools', 'BashExecutor.cjs');
  const codeExecutorPath = path.join(agentsCjsDir, 'tools', 'CodeExecutor.cjs');
  const agentsIndexPath = path.join(agentsCjsDir, 'index.cjs');
  const agentsRunPath = path.join(agentsCjsDir, 'run.cjs');
  const llmInitPath = path.join(agentsCjsDir, 'llm', 'init.cjs');
  const unrelatedIndexPath = path.join(tmpDir, 'other', 'index.cjs');
  const unrelatedBashPath = path.join(tmpDir, 'other', 'tools', 'BashExecutor.cjs');
  const dataProviderPath = path.join(tmpDir, 'packages', 'data-provider', 'index.js');
  const apiPackagePath = path.join(tmpDir, 'packages', 'api', 'index.js');

  writeFile(
    bashExecutorPath,
    `
const desc = 'Run bash commands.\\n- No network access available.\\n- Files in /mnt/data.';
const statefulDesc = 'Run stateful bash.\\n- No network access available.';
class FakeTool {
  constructor(description) {
    this.name = 'execute_bash';
    if (description !== undefined) {
      this.description = description;
    }
  }
  invoke() {
    return 'ok';
  }
}
module.exports = {
  BashExecutionToolDescription: desc,
  StatefulBashExecutionToolDescription: statefulDesc,
  BashExecutionToolDefinition: { name: 'execute_bash', description: desc },
  buildBashExecutionToolDescription(stateful) {
    return stateful ? statefulDesc : desc;
  },
  createBashExecutionTool(mode) {
    if (mode === 'missing') return new FakeTool(undefined);
    if (mode === 'nonstring') return { description: 42 };
    if (mode === 'null') return null;
    return new FakeTool(desc);
  },
};
`,
  );

  writeFile(
    codeExecutorPath,
    `
const desc = 'Run code.\\n- No network access available.\\n- Output returned.';
const statefulDesc = 'Run stateful code.\\n- No network access available.';
module.exports = {
  CodeExecutionToolDescription: desc,
  StatefulCodeExecutionToolDescription: statefulDesc,
  CodeExecutionToolDefinition: { name: 'execute_code', description: desc },
  buildCodeExecutionToolDescription(stateful) {
    return stateful ? statefulDesc : desc;
  },
  createCodeExecutionTool(mode) {
    if (mode === 'missing') return { name: 'execute_code' };
    if (mode === 'nonstring') return { name: 'execute_code', description: { text: desc } };
    return { name: 'execute_code', description: desc };
  },
};
`,
  );

  writeFile(
    agentsIndexPath,
    `
module.exports = {
  loadBash: () => require('./tools/BashExecutor.cjs'),
  loadCode: () => require('./tools/CodeExecutor.cjs'),
};
`,
  );

  writeFile(
    unrelatedBashPath,
    `
module.exports = {
  BashExecutionToolDescription: 'Unrelated\\n- No network access available.',
};
`,
  );
  writeFile(unrelatedIndexPath, `module.exports = require('./tools/BashExecutor.cjs');`);

  writeFile(
    llmInitPath,
    `
module.exports = {
  initializeModel(params) {
    return params;
  },
};
`,
  );
  writeFile(agentsRunPath, `module.exports = require('./llm/init.cjs');`);

  writeFile(
    dataProviderPath,
    `
module.exports = {
  providerEndpointMap: {},
  parseCompactConvo(params) {
    return params;
  },
};
`,
  );

  writeFile(
    apiPackagePath,
    `
module.exports = {
  maxTokensMap: { openAI: {}, agents: {}, custom: {}, google: {}, azureOpenAI: {} },
  providerConfigMap: {
    google(params) {
      return params;
    },
  },
};
`,
  );

  // 1. Relative require from /@librechat/agents/dist/cjs/ rewrites BashExecutor and CodeExecutor.
  const agentsIndex = require(agentsIndexPath);
  const bashMod = agentsIndex.loadBash();
  const bashModAgain = agentsIndex.loadBash();
  assert.strictEqual(bashMod, bashModAgain, 'WeakMap cache should return identical wrapper');

  assert.ok(bashMod.BashExecutionToolDescription.includes(EXPECTED_NETWORK_LINE));
  assert.ok(!bashMod.BashExecutionToolDescription.includes('- No network access available.'));
  assert.ok(bashMod.StatefulBashExecutionToolDescription.includes(EXPECTED_NETWORK_LINE));
  assert.strictEqual(bashMod.BashExecutionToolDefinition.name, 'execute_bash');
  assert.ok(bashMod.BashExecutionToolDefinition.description.includes(EXPECTED_NETWORK_LINE));
  assert.ok(bashMod.buildBashExecutionToolDescription(false).includes(EXPECTED_NETWORK_LINE));
  assert.ok(bashMod.buildBashExecutionToolDescription(true).includes(EXPECTED_NETWORK_LINE));

  const bashTool = bashMod.createBashExecutionTool();
  assert.ok(bashTool.description.includes(EXPECTED_NETWORK_LINE));
  assert.strictEqual(bashTool.invoke(), 'ok', 'Prototype methods must remain intact');
  assert.strictEqual(bashMod.createBashExecutionTool('missing').description, undefined);
  assert.strictEqual(bashMod.createBashExecutionTool('nonstring').description, 42);
  assert.strictEqual(bashMod.createBashExecutionTool('null'), null);

  const codeMod = agentsIndex.loadCode();
  assert.ok(codeMod.CodeExecutionToolDescription.includes(EXPECTED_NETWORK_LINE));
  assert.ok(!codeMod.CodeExecutionToolDescription.includes('- No network access available.'));
  assert.ok(codeMod.StatefulCodeExecutionToolDescription.includes(EXPECTED_NETWORK_LINE));
  assert.strictEqual(codeMod.CodeExecutionToolDefinition.name, 'execute_code');
  assert.ok(codeMod.CodeExecutionToolDefinition.description.includes(EXPECTED_NETWORK_LINE));
  assert.ok(codeMod.buildCodeExecutionToolDescription(false).includes(EXPECTED_NETWORK_LINE));
  assert.ok(codeMod.buildCodeExecutionToolDescription(true).includes(EXPECTED_NETWORK_LINE));
  assert.ok(codeMod.createCodeExecutionTool().description.includes(EXPECTED_NETWORK_LINE));
  assert.strictEqual(codeMod.createCodeExecutionTool('missing').description, undefined);
  assert.strictEqual(typeof codeMod.createCodeExecutionTool('nonstring').description, 'object');

  // 2. Direct absolute loads return the same cached wrapped modules.
  assert.strictEqual(require(bashExecutorPath), bashMod);
  assert.strictEqual(require(codeExecutorPath), codeMod);

  // 3. Unrelated modules with the same relative path are untouched.
  const unrelatedMod = require(unrelatedIndexPath);
  assert.ok(unrelatedMod.BashExecutionToolDescription.includes('- No network access available.'));

  // 4. Existing hooks (initializeModel, data-provider, @librechat/api) remain intact.
  const runInit = require(agentsRunPath);
  const initResult = runInit.initializeModel({
    provider: 'google',
    clientOptions: { model: 'gemini-4-hydrogen', thinkingLevel: 'low' },
  });
  assert.strictEqual(initResult.clientOptions.thinkingConfig.thinkingLevel, 'LOW');

  const dataProvider = require(path.join(tmpDir, 'packages', 'data-provider'));
  assert.strictEqual(dataProvider.providerEndpointMap.google, 'google');
  const cleaned = dataProvider.parseCompactConvo({
    conversation: { maxContextTokens: 1024, title: 'kept' },
  });
  assert.strictEqual('maxContextTokens' in cleaned.conversation, false);
  assert.strictEqual(cleaned.conversation.title, 'kept');

  const apiPkg = require(path.join(tmpDir, 'packages', 'api'));
  assert.strictEqual(apiPkg.maxTokensMap.google['gemini-4-neon'], 1048576);
  const neonParams = apiPkg.providerConfigMap.google({
    model_parameters: { model: 'gemini-4-neon' },
  });
  assert.strictEqual(neonParams.model_parameters.thinkingLevel, 'high');
  const carbonParams = apiPkg.providerConfigMap.google({
    model_parameters: { model: 'gemini-4-carbon' },
  });
  assert.strictEqual(carbonParams.model_parameters.thinkingLevel, 'medium');
} finally {
  fs.rmSync(tmpDir, { recursive: true, force: true });
}
