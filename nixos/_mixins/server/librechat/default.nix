{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty.network) tailNet;
  registry = builtins.fromTOML (builtins.readFile ../../../../lib/registry-systems.toml);
  llamaRuntime = import ../llama-server/runtime.nix { inherit lib; };
  remoteInferenceHosts = [
    "skrye"
    "zannah"
  ];
  mkRemoteLlamaSwapEndpoint =
    node:
    let
      entry = registry.${node};
      runtimeModels =
        (llamaRuntime.mkRuntime {
          acceleration = entry.gpu.compute.acceleration or null;
          hostVramGiB = entry.gpu.compute.vram or 0;
        }).selectedRuntimeModels;
      generationRoles = lib.filterAttrs (_role: model: !model.isEmbedding) runtimeModels;
      generationModels = lib.mapAttrsToList (_role: model: model.publicName) generationRoles;
      tokenConfig = builtins.listToAttrs (
        lib.mapAttrsToList (_role: model: {
          name = model.publicName;
          value = {
            prompt = 0;
            completion = 0;
            context = model.maxContext;
          };
        }) generationRoles
      );
      titleModel =
        if runtimeModels ? smallMedia then
          runtimeModels.smallMedia.publicName
        else
          lib.head generationModels;
    in
    {
      name = "LlamaSwap (${node})";
      apiKey = "none";
      baseURL = "http://${node}.${tailNet}:8080/v1";
      models = {
        default = generationModels;
        fetch = true;
      };
      inherit tokenConfig titleModel;
      titleConvo = true;
    };
  cloudflareSopsFile = ../../../../secrets + "/cloudflare.yaml";
  hasCloudflareSopsFile = builtins.pathExists cloudflareSopsFile;
  assistantsRoot = ../../../../home-manager/_mixins/agentic/assistants;
  assistantsCompose = import (assistantsRoot + "/compose.nix") {
    inherit lib pkgs;
    basePath = assistantsRoot;
    gwsEnabled = false;
  };
  mcpServerNames = [
    "exa"
    "cloudflare-docs"
    "cloudflare-api"
    "context7"
    "linear"
    "nixos"
  ];
  mcpTools = lib.concatMap (server: [
    "sys__server__sys_mcp_${server}"
    "sys__all__sys_mcp_${server}"
  ]) mcpServerNames;
  stripFrontmatter =
    text:
    let
      lines = lib.splitString "\n" text;
      rest = lib.drop 1 lines;
      closingIndex = lib.lists.findFirstIndex (line: line == "---") null rest;
    in
    if lib.head lines == "---" && closingIndex != null then
      lib.trim (lib.concatStringsSep "\n" (lib.drop (closingIndex + 1) rest))
    else
      lib.trim text;
  binarySkillExtensions = [
    ".png"
    ".jpg"
    ".jpeg"
    ".gif"
    ".webp"
    ".ico"
    ".pdf"
    ".zip"
    ".woff"
    ".woff2"
    ".ttf"
    ".otf"
  ];
  collectSkillFiles =
    skillDir:
    let
      walk =
        prefix: dir:
        lib.concatLists (
          lib.mapAttrsToList (
            entryName: entryType:
            let
              relativePath = if prefix == "" then entryName else "${prefix}/${entryName}";
              fullPath = dir + "/${entryName}";
              lowerPath = lib.toLower relativePath;
              isBinary = lib.any (ext: lib.hasSuffix ext lowerPath) binarySkillExtensions;
              isExecutable =
                lib.hasPrefix "scripts/" relativePath
                || lib.hasSuffix ".sh" relativePath
                || lib.hasSuffix ".py" relativePath;
            in
            if
              prefix == ""
              && lib.elem entryName [
                "SKILL.md"
                "header.toml"
              ]
            then
              [ ]
            else if entryType == "directory" then
              walk relativePath fullPath
            else
              let
                content = if isBinary then null else builtins.readFile fullPath;
              in
              [
                {
                  inherit
                    relativePath
                    content
                    isBinary
                    isExecutable
                    ;
                  filename = entryName;
                  filepath = "${fullPath}";
                  bytes = if isBinary then 0 else builtins.stringLength content;
                  category =
                    if lib.hasPrefix "references/" relativePath then
                      "reference"
                    else if lib.hasPrefix "scripts/" relativePath then
                      "script"
                    else if lib.hasPrefix "assets/" relativePath then
                      "asset"
                    else
                      "other";
                  mimeType =
                    if lib.hasSuffix ".md" relativePath then
                      "text/markdown"
                    else if lib.hasSuffix ".json" relativePath then
                      "application/json"
                    else if isBinary then
                      "application/octet-stream"
                    else
                      "text/plain";
                }
              ]
          ) (builtins.readDir dir)
        );
    in
    walk "" skillDir;
  provisionedSkillNames = lib.sort (a: b: a < b) (builtins.attrNames assistantsCompose.skillDirs);
  provisionedAgentNames = lib.sort (a: b: a < b) (builtins.attrNames assistantsCompose.agentDirs);
  provisionedCommandNames = lib.sort (a: b: a < b) (
    builtins.attrNames (lib.filterAttrs (_: entry: !entry.secret) assistantsCompose.commandRegistry)
  );
  sharedAgentNames = [
    "casper"
    "morph"
    "penfold"
    "velma"
  ];
  sharedSkillNames = [
    "communication-rules"
    "deep-research"
    "delegate-task"
    "diagram-design"
    "frontend-design"
    "logo-design"
    "marp-presentations"
    "web-interface-guidelines"
    "writing-well"
  ];
  librechatAssistantsManifest = pkgs.writeText "librechat-assistants-manifest.json" (
    builtins.toJSON {
      agents = map (
        name:
        let
          agentDir = assistantsRoot + "/agents/${name}";
          header = assistantsCompose.readHeader agentDir;
          claudeModel = header.routing.claude.model or "";
        in
        {
          id = "agent_${name}";
          inherit name mcpServerNames;
          shared = lib.elem name sharedAgentNames;
          description = header.common.description;
          instructions =
            lib.trim (builtins.readFile (agentDir + "/prompt.md")) + "\n\n" + assistantsCompose.houseStyleBody;
          provider = "anthropic";
          model = if claudeModel == "claude-opus-5-5" then "claude-opus-5-5" else "claude-sonnet-5-5";
          tools = [
            "execute_code"
            "memory"
          ]
          ++ mcpTools;
        }
      ) provisionedAgentNames;
      skills = map (
        skillName:
        let
          skillDir = assistantsRoot + "/skills/${skillName}";
          header = assistantsCompose.readHeader skillDir;
        in
        {
          name = skillName;
          displayTitle = skillName;
          shared = lib.elem skillName sharedSkillNames;
          description = header.common.description;
          body =
            if builtins.pathExists (skillDir + "/SKILL.md") then
              lib.trim (builtins.readFile (skillDir + "/SKILL.md"))
            else
              stripFrontmatter assistantsCompose.composeSkills.${skillName}.content;
          frontmatter = assistantsCompose.headerFor "skill" "claude" skillName skillDir;
          files = collectSkillFiles skillDir;
        }
      ) provisionedSkillNames;
      commands = map (
        cmdName:
        let
          entry = assistantsCompose.commandRegistry.${cmdName};
        in
        {
          command = cmdName;
          name = cmdName;
          oneliner = entry.header.common.description;
          prompt = lib.trim (builtins.readFile (entry.path + "/command.md"));
        }
      ) provisionedCommandNames;
    }
  );
  librechatProvisionUsers = pkgs.writeShellApplication {
    name = "librechat-provision-users";
    runtimeInputs = [ pkgs.mongosh ];
    # Single-quoted strings in the mongosh --eval block are intentional
    # JavaScript, not shell expressions; disable shellcheck accordingly.
    checkPhase = "";
    text = ''
      mongoUri="mongodb://127.0.0.1:27017/librechat"
      export MANIFEST_FILE="''${MANIFEST_FILE:-${librechatAssistantsManifest}}"

      : "''${HASH_MARTIN:?}"
      : "''${HASH_LOUISE:?}"
      : "''${HASH_AGATHA:?}"

      upsertUser() {
        local email="$1"
        local name="$2"
        local username="$3"
        local role="$4"
        local hashFile="$5"
        local passwordHash

        passwordHash="$(<"$hashFile")"

        EMAIL="$email" \
        NAME="$name" \
        USERNAME="$username" \
        ROLE="$role" \
        PASSWORD_HASH="$passwordHash" \
          mongosh --quiet "$mongoUri" --eval '
            const now = new Date();

            db.users.updateOne(
              { email: process.env.EMAIL },
              {
                $set: {
                  email: process.env.EMAIL,
                  name: process.env.NAME,
                  username: process.env.USERNAME,
                  password: process.env.PASSWORD_HASH,
                  provider: "local",
                  role: process.env.ROLE,
                  emailVerified: true,
                  avatar: null,
                  updatedAt: now,
                },
                $setOnInsert: {
                  createdAt: now,
                },
              },
              { upsert: true },
            );
          '
      }

      upsertUser "martin@wimpress.org" "Martin Wimpress" "martin" "ADMIN" "$HASH_MARTIN"
      upsertUser "louise@wimpress.org" "Louise Wimpress" "louise" "USER" "$HASH_LOUISE"
      upsertUser "agatha@wimpress.org" "Agatha Wimpress" "agatha" "USER" "$HASH_AGATHA"

      mongosh --quiet "$mongoUri" --eval '
        const now = new Date();
        db.configs.updateOne(
          {
            principalType: "role",
            principalId: "ADMIN",
          },
          {
            $set: {
              principalType: "role",
              principalId: "ADMIN",
              principalModel: "Role",
              priority: 10,
              isActive: true,
              overrides: {
                mcpServers: {
                  "cloudflare-docs": {
                    type: "streamable-http",
                    url: "https://docs.mcp.cloudflare.com/mcp",
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  "cloudflare-api": {
                    type: "streamable-http",
                    url: "https://mcp.cloudflare.com/mcp",
                    headers: {
                      Authorization: "Bearer ''${CLOUDFLARE_API_TOKEN}",
                    },
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  context7: {
                    type: "streamable-http",
                    url: "https://mcp.context7.com/mcp",
                    headers: {
                      Authorization: "Bearer ''${CONTEXT7_API_KEY}",
                    },
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  linear: {
                    type: "streamable-http",
                    url: "https://mcp.linear.app/mcp",
                    headers: {
                      Authorization: "Bearer ''${LINEAR_API_KEY}",
                    },
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  nixos: {
                    type: "streamable-http",
                    url: "http://127.0.0.1:3081/mcp",
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                },
              },
              updatedAt: now,
            },
            $setOnInsert: {
              createdAt: now,
            },
          },
          { upsert: true },
        );

        const manifest = JSON.parse(fs.readFileSync(process.env.MANIFEST_FILE, "utf8"));
        const martin = db.users.findOne({ email: "martin@wimpress.org" });
        if (!martin) {
          throw new Error("Expected user martin@wimpress.org was not found in db.users");
        }

        const ensureRole = (accessRoleId, resourceType, permBits, name, description) => {
          db.accessroles.updateOne(
            { accessRoleId },
            {
              $setOnInsert: {
                accessRoleId,
                name,
                description,
                resourceType,
                permBits,
                createdAt: now,
                updatedAt: now,
              },
            },
            { upsert: true },
          );
          return db.accessroles.findOne({ accessRoleId });
        };

        const agentOwnerRole = ensureRole(
          "agent_owner",
          "agent",
          15,
          "com_ui_role_owner",
          "com_ui_role_owner_desc",
        );
        const agentViewerRole = ensureRole(
          "agent_viewer",
          "agent",
          1,
          "com_ui_role_viewer",
          "com_ui_role_viewer_desc",
        );
        const promptGroupOwnerRole = ensureRole(
          "promptGroup_owner",
          "promptGroup",
          15,
          "com_ui_role_owner",
          "com_ui_role_owner_desc",
        );
        const skillOwnerRole = ensureRole(
          "skill_owner",
          "skill",
          15,
          "com_ui_role_owner",
          "com_ui_role_owner_desc",
        );
        const skillViewerRole = ensureRole(
          "skill_viewer",
          "skill",
          1,
          "com_ui_role_viewer",
          "com_ui_role_viewer_desc",
        );

        const upsertOwnerAcl = (resourceType, resourceId, roleId) => {
          db.aclentries.updateOne(
            {
              principalType: "user",
              principalId: martin._id,
              resourceType,
              resourceId,
            },
            {
              $set: {
                principalType: "user",
                principalId: martin._id,
                principalModel: "User",
                resourceType,
                resourceId,
                permBits: 15,
                roleId,
                grantedBy: martin._id,
                grantedAt: now,
                updatedAt: now,
              },
              $setOnInsert: {
                createdAt: now,
              },
            },
            { upsert: true },
          );
        };

        const syncPublicViewerAcl = (resourceType, resourceId, roleId, isShared) => {
          if (isShared) {
            db.aclentries.updateOne(
              {
                principalType: "public",
                resourceType,
                resourceId,
              },
              {
                $set: {
                  principalType: "public",
                  resourceType,
                  resourceId,
                  permBits: 1,
                  roleId,
                  grantedBy: martin._id,
                  grantedAt: now,
                  updatedAt: now,
                },
                $setOnInsert: {
                  createdAt: now,
                },
              },
              { upsert: true },
            );
          } else {
            db.aclentries.deleteMany({
              principalType: "public",
              resourceType,
              resourceId,
            });
          }
        };

        const skillIds = [];
        for (const skill of manifest.skills) {
          db.skills.updateOne(
            { name: skill.name, author: martin._id },
            {
              $set: {
                name: skill.name,
                displayTitle: skill.displayTitle,
                description: skill.description,
                body: skill.body,
                frontmatter: skill.frontmatter,
                category: "",
                disableModelInvocation: false,
                userInvocable: true,
                defaultActiveOnShare: Boolean(skill.shared),
                author: martin._id,
                authorName: martin.name,
                source: "inline",
                fileCount: skill.files.length,
                alwaysApply: false,
                updatedAt: now,
              },
              $setOnInsert: {
                version: 1,
                createdAt: now,
              },
            },
            { upsert: true },
          );

          const skillDoc = db.skills.findOne({ name: skill.name, author: martin._id });
          skillIds.push(skillDoc._id.toString());

          const currentRelativePaths = [];
          for (const f of skill.files) {
            currentRelativePaths.push(f.relativePath);
            const fileId =
              "nix-" + skill.name + "-" + f.relativePath.replace(/[^a-zA-Z0-9._-]/g, "_");
            db.skillfiles.updateOne(
              { skillId: skillDoc._id, relativePath: f.relativePath },
              {
                $set: {
                  skillId: skillDoc._id,
                  relativePath: f.relativePath,
                  file_id: fileId,
                  filename: f.filename,
                  filepath: f.filepath,
                  source: "local",
                  mimeType: f.mimeType,
                  bytes: f.bytes,
                  category: f.category,
                  isExecutable: Boolean(f.isExecutable),
                  isBinary: Boolean(f.isBinary),
                  content: f.content,
                  author: martin._id,
                  updatedAt: now,
                },
                $setOnInsert: {
                  createdAt: now,
                },
              },
              { upsert: true },
            );
          }

          db.skillfiles.deleteMany({
            skillId: skillDoc._id,
            relativePath: { $nin: currentRelativePaths },
          });

          upsertOwnerAcl("skill", skillDoc._id, skillOwnerRole._id);
          syncPublicViewerAcl("skill", skillDoc._id, skillViewerRole._id, Boolean(skill.shared));
        }

        const allAgentIds = manifest.agents.map((a) => a.id);

        for (const agent of manifest.agents) {
          const otherAgentIds = allAgentIds.filter((id) => id !== agent.id);
          const isCoordinator = agent.name === "penfold";
          const subagentsConfig = {
            enabled: isCoordinator,
            allowSelf: false,
            agent_ids: isCoordinator ? otherAgentIds : [],
          };
          const versionEntry = {
            name: agent.name,
            description: agent.description,
            instructions: agent.instructions,
            provider: agent.provider,
            model: agent.model,
            model_parameters: {},
            tools: agent.tools,
            mcpServerNames: agent.mcpServerNames,
            skills: skillIds,
            skills_enabled: true,
            skills_scope: "all",
            stateful_code_sessions: true,
            subagents: subagentsConfig,
            edges: [],
            createdAt: now,
            updatedAt: now,
          };

          db.agents.updateOne(
            { id: agent.id },
            {
              $set: {
                id: agent.id,
                name: agent.name,
                description: agent.description,
                instructions: agent.instructions,
                provider: agent.provider,
                model: agent.model,
                model_parameters: {},
                tools: agent.tools,
                mcpServerNames: agent.mcpServerNames,
                skills: skillIds,
                skills_enabled: true,
                skills_scope: "all",
                stateful_code_sessions: true,
                subagents: subagentsConfig,
                author: martin._id,
                authorName: martin.name,
                category: "general",
                is_promoted: false,
                edges: [],
                conversation_starters: [],
                tool_resources: {},
                versions: [versionEntry],
                updatedAt: now,
              },
              $setOnInsert: {
                createdAt: now,
              },
            },
            { upsert: true },
          );

          const agentDoc = db.agents.findOne({ id: agent.id });
          upsertOwnerAcl("agent", agentDoc._id, agentOwnerRole._id);
          syncPublicViewerAcl("agent", agentDoc._id, agentViewerRole._id, Boolean(agent.shared));
        }

        db.conversations.updateMany(
          { maxContextTokens: { $lte: 1024 } },
          { $unset: { maxContextTokens: "" } },
        );
        db.presets.updateMany(
          { maxContextTokens: { $lte: 1024 } },
          { $unset: { maxContextTokens: "" } },
        );

        for (const cmd of manifest.commands) {
          db.promptgroups.updateOne(
            { command: cmd.command, author: martin._id },
            {
              $set: {
                name: cmd.name,
                command: cmd.command,
                oneliner: cmd.oneliner,
                category: "",
                author: martin._id,
                authorName: martin.name,
                updatedAt: now,
              },
              $setOnInsert: {
                numberOfGenerations: 0,
                createdAt: now,
              },
            },
            { upsert: true },
          );

          const groupDoc = db.promptgroups.findOne({ command: cmd.command, author: martin._id });

          db.prompts.updateOne(
            { groupId: groupDoc._id },
            {
              $set: {
                groupId: groupDoc._id,
                author: martin._id,
                prompt: cmd.prompt,
                type: "text",
                updatedAt: now,
              },
              $setOnInsert: {
                createdAt: now,
              },
            },
            { upsert: true },
          );

          const promptDoc = db.prompts.findOne({ groupId: groupDoc._id });
          db.promptgroups.updateOne(
            { _id: groupDoc._id },
            { $set: { productionId: promptDoc._id } },
          );

          upsertOwnerAcl("promptGroup", groupDoc._id, promptGroupOwnerRole._id);
        }
      '
    '';
  };
in
{
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/cliproxyapi.nix"
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "librechat") {
    environment.systemPackages = [
      config.services.cliproxyapi.package
    ];

    environment.shellAliases = {
      cliproxyapi-codex-device-login = "sudo -u cliproxyapi cliproxyapi -config /var/lib/cliproxyapi/config.yaml -codex-device-login";
      cliproxyapi-codex-login = "sudo -u cliproxyapi cliproxyapi -config /var/lib/cliproxyapi/config.yaml -codex-login -no-browser";
      cliproxyapi-log = "journalctl _SYSTEMD_UNIT=cliproxyapi.service";
      librechat-log = "journalctl _SYSTEMD_UNIT=librechat.service";
    };

    sops.secrets.ANTHROPIC_API_KEY = {
      sopsFile = ../../../../secrets/ai.yaml;
      path = "/run/secrets/ANTHROPIC_API_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.GEMINI_API_KEY = {
      sopsFile = ../../../../secrets/ai.yaml;
      path = "/run/secrets/GEMINI_API_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CONTEXT7_API_KEY = {
      sopsFile = ../../../../secrets/mcp.yaml;
      path = "/run/secrets/CONTEXT7_API_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.LINEAR_API_KEY = {
      sopsFile = ../../../../secrets/linear.yaml;
      key = "wimpysworld";
      path = "/run/secrets/LINEAR_API_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CLOUDFLARE_API_TOKEN = lib.mkIf hasCloudflareSopsFile {
      sopsFile = cloudflareSopsFile;
      path = "/run/secrets/CLOUDFLARE_API_TOKEN";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CREDS_KEY = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/CREDS_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CREDS_IV = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/CREDS_IV";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.JWT_SECRET = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/JWT_SECRET";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.JWT_REFRESH_SECRET = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/JWT_REFRESH_SECRET";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.MEILI_MASTER_KEY = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/MEILI_MASTER_KEY";
      owner = "root";
      group = "root";
      mode = "0440";
    };

    sops.secrets.USER_PW_MARTIN = {
      sopsFile = ../../../../secrets/librechat.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.USER_PW_LOUISE = {
      sopsFile = ../../../../secrets/librechat.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.USER_PW_AGATHA = {
      sopsFile = ../../../../secrets/librechat.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Create the LibreChat tunnel in Cloudflare first, then encrypt the
    # tunnel token from the dashboard install connector flow into
    # secrets/cloudflare.yaml as CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT before
    # enabling the tunnel here.
    sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT = lib.mkIf hasCloudflareSopsFile {
      sopsFile = cloudflareSopsFile;
      path = "/run/secrets/CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Upstream's services.librechat.openFirewall references an undefined
    # cfg.port in nixpkgs ec942ba, so it throws when enabled. Leave it off and
    # open the firewall from env.PORT, matching the previous vendored module.
    networking.firewall.allowedTCPPorts = [
      (lib.toInt config.services.librechat.env.PORT)
    ];

    services.librechat = {
      enable = true;
      package = lib.mkDefault pkgs.librechat;
      meilisearch.enable = lib.mkDefault true;
      env = {
        ALLOW_EMAIL_LOGIN = lib.mkDefault true;
        ALLOWED_EMAIL_DOMAINS = lib.mkDefault "wimpress.org";
        ALLOW_REGISTRATION = lib.mkDefault false;
        ALLOW_SOCIAL_LOGIN = lib.mkDefault false;
        ALLOW_UNVERIFIED_EMAIL_LOGIN = lib.mkDefault true;
        GOOGLE_MODELS = lib.mkDefault "gemini-4-argon,gemini-3.8-flash";
        HOST = lib.mkDefault "0.0.0.0";
        LIBRECHAT_CODE_API_KEY = lib.mkDefault "local-sandbox";
        LIBRECHAT_CODE_BASEURL = lib.mkDefault "http://127.0.0.1:3082";
        LIBRECHAT_CODE_BASEURL_STATEFUL = lib.mkDefault "http://127.0.0.1:3082";
        MONGO_URI = lib.mkIf (noughtyLib.hostHasTag "mongodb") (
          lib.mkDefault "mongodb://localhost:27017/librechat"
        );
        NODE_OPTIONS = lib.mkDefault "--require ${./preload-tokens.cjs}";
      };
      credentials = {
        ANTHROPIC_API_KEY = config.sops.secrets.ANTHROPIC_API_KEY.path;
        CLOUDFLARE_API_TOKEN = lib.mkIf hasCloudflareSopsFile config.sops.secrets.CLOUDFLARE_API_TOKEN.path;
        CONTEXT7_API_KEY = config.sops.secrets.CONTEXT7_API_KEY.path;
        CREDS_IV = config.sops.secrets.CREDS_IV.path;
        CREDS_KEY = config.sops.secrets.CREDS_KEY.path;
        GEMINI_API_KEY = config.sops.secrets.GEMINI_API_KEY.path;
        GOOGLE_KEY = config.sops.secrets.GEMINI_API_KEY.path;
        JWT_REFRESH_SECRET = config.sops.secrets.JWT_REFRESH_SECRET.path;
        JWT_SECRET = config.sops.secrets.JWT_SECRET.path;
        LINEAR_API_KEY = config.sops.secrets.LINEAR_API_KEY.path;
      };
      settings = lib.mkDefault {
        version = "1.3.6";
        interface = {
          agentSelectorLimit = 20;
        };
        memory = {
          disabled = false;
          personalize = true;
          charLimit = 10000;
          messageWindowSize = 5;
          agent = {
            provider = "anthropic";
            model = "claude-sonnet-5-5";
          };
        };
        summarization = {
          enabled = true;
          provider = "google";
          model = "gemini-4-argon";
        };
        endpoints = {
          allowedAddresses = [
            "127.0.0.1:8317"
          ]
          ++ map (node: "${node}.${tailNet}:8080") remoteInferenceHosts;
          agents = {
            maxSubagents = 12;
            capabilities = [
              "deferred_tools"
              "execute_code"
              "stateful_code_sessions"
              "file_search"
              "web_search"
              "artifacts"
              "subagents"
              "actions"
              "context"
              "skills"
              "memory"
              "ask_user_question"
              "tools"
              "chain"
              "ocr"
            ];
          };
          anthropic = {
            models = [
              "claude-sonnet-5-5"
              "claude-opus-5-5"
            ];
            titleConvo = true;
            titleModel = "claude-sonnet-5-5";
          };
          google = {
            titleConvo = true;
            titleModel = "gemini-3.8-flash";
          };
          custom = [
            {
              name = "OpenAI (Codex)";
              apiKey = "cliproxyapi";
              baseURL = "http://127.0.0.1:8317/v1";
              models = {
                default = [
                  "gpt-6.1-sol"
                  "gpt-6-astra"
                  "gpt-6.1-terra"
                  "gpt-6-luna"
                ];
                fetch = true;
              };
              tokenConfig = {
                "gpt-6.1-sol" = {
                  prompt = 0;
                  completion = 0;
                  context = 1050000;
                };
                "gpt-6-astra" = {
                  prompt = 0;
                  completion = 0;
                  context = 1050000;
                };
                "gpt-6.1-terra" = {
                  prompt = 0;
                  completion = 0;
                  context = 1050000;
                };
                "gpt-6-luna" = {
                  prompt = 0;
                  completion = 0;
                  context = 1050000;
                };
              };
              titleConvo = true;
              titleModel = "gpt-6-luna";
            }
          ]
          ++ map mkRemoteLlamaSwapEndpoint remoteInferenceHosts;
        };
        mcpSettings = {
          allowedAddresses = [
            "127.0.0.1:3081"
            "127.0.0.1:3082"
          ];
        };
        mcpServers = {
          exa = {
            type = "streamable-http";
            url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
            requiresOAuth = false;
            chatMenu = true;
            startup = true;
          };
        };
      };
    };

    services.meilisearch.masterKeyFile = lib.mkDefault config.sops.secrets.MEILI_MASTER_KEY.path;

    services.cliproxyapi = {
      enable = true;
      package = lib.mkDefault pkgs.cliproxyapi;
      settings = {
        server = {
          host = "127.0.0.1";
          port = 8317;
        };
        oauth = {
          auth-dir = "/var/lib/cliproxyapi";
        };
      };
    };

    systemd.services.librechat-mcp-nixos = {
      description = "Local NixOS MCP server for LibreChat";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.nix ];
      environment = {
        FASTMCP_CHECK_FOR_UPDATES = "off";
        HOME = "/tmp";
        MCP_NIXOS_HOST = "127.0.0.1";
        MCP_NIXOS_PATH = "/mcp";
        MCP_NIXOS_PORT = "3081";
        MCP_NIXOS_TRANSPORT = "http";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe pkgs.mcp-nixos;
        Restart = lib.mkDefault "always";
        RestartSec = lib.mkDefault 5;
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    systemd.services.librechat-code-sandbox = {
      description = "Local Code Interpreter sandbox service for LibreChat";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.bash
        pkgs.bubblewrap
        pkgs.coreutils
        pkgs.curl
        pkgs.fd
        pkgs.file
        pkgs.findutils
        pkgs.gawk
        pkgs.git
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gnutar
        pkgs.gzip
        pkgs.jq
        pkgs.nodejs
        pkgs.python3
        pkgs.ripgrep
        pkgs.unzip
      ];
      environment = {
        HOST = "127.0.0.1";
        PORT = "3082";
        STATE_DIR = "/var/lib/librechat-code-sandbox";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.python3} ${./code-sandbox.py}";
        Restart = lib.mkDefault "always";
        RestartSec = lib.mkDefault 5;
        DynamicUser = true;
        StateDirectory = "librechat-code-sandbox";
        TemporaryFileSystem = "/mnt:mode=0755";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    systemd.services.librechat = {
      after = [
        "cliproxyapi.service"
        "librechat-code-sandbox.service"
        "librechat-mcp-nixos.service"
      ]
      ++ lib.optionals (noughtyLib.hostHasTag "mongodb") [
        "mongodb.service"
        "librechat-provision-users.service"
      ];
      wants = [
        "cliproxyapi.service"
        "librechat-code-sandbox.service"
        "librechat-mcp-nixos.service"
      ]
      ++ lib.optionals (noughtyLib.hostHasTag "mongodb") [
        "mongodb.service"
        "librechat-provision-users.service"
      ];
    };

    systemd.services.librechat-provision-users = lib.mkIf (noughtyLib.hostHasTag "mongodb") {
      description = "Provision initial LibreChat user accounts.";
      wantedBy = [ "multi-user.target" ];
      after = [ "mongodb.service" ];
      wants = [ "mongodb.service" ];
      environment = {
        HASH_MARTIN = config.sops.secrets.USER_PW_MARTIN.path;
        HASH_LOUISE = config.sops.secrets.USER_PW_LOUISE.path;
        HASH_AGATHA = config.sops.secrets.USER_PW_AGATHA.path;
        MANIFEST_FILE = "${librechatAssistantsManifest}";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = lib.getExe librechatProvisionUsers;
      };
    };

    systemd.services.cloudflared-librechat = lib.mkIf hasCloudflareSopsFile {
      description = "Cloudflare Tunnel connector for LibreChat";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.cloudflared)
          "tunnel"
          "--no-autoupdate"
          "run"
          "--token-file"
          config.sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT.path
        ];
        Restart = lib.mkDefault "always";
        RestartSec = lib.mkDefault 5;
        User = lib.mkDefault "root";
        Group = lib.mkDefault "root";

        # Restrict the connector to outbound access and secret reads.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    # Remotely-managed tunnels store published application routing in
    # Cloudflare. Configure ai.wimpys.world and ai.wimpress.org ->
    # http://127.0.0.1:3080 in the Cloudflare dashboard or API for this tunnel.
  };
}
