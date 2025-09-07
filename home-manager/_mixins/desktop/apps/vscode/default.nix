{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" "martin.wimpress" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor) {
  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default
  ];

  home = {
    file = {
      "${config.xdg.configHome}/Code/User/mcp.json".text = builtins.readFile ./mcp.json;
      "${config.xdg.configHome}/Code/User/prompts/copilot.instructions.md".text = builtins.readFile ./copilot.instructions.md;
      "${config.xdg.configHome}/Code/User/prompts/dilbert.chatmode.md".text = builtins.readFile ./dilbert.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/gonzales.chatmode.md".text = builtins.readFile ./gonzales.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/linus.chatmode.md".text = builtins.readFile ./linus.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/luthor.chatmode.md".text = builtins.readFile ./luthor.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/nixpert.chatmode.md".text = builtins.readFile ./nixpert.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/otto.chatmode.md".text = builtins.readFile ./otto.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/penry.chatmode.md".text = builtins.readFile ./penry.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/tessl.chatmode.md".text = builtins.readFile ./tessl.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/velma.chatmode.md".text = builtins.readFile ./velma.chatmode.md;
      "${config.xdg.configHome}/Code/User/prompts/create-code.prompt.md".text = builtins.readFile ./create-code.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/create-conventional-commit.prompt.md".text = builtins.readFile ./create-conventional-commit.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/create-readme.prompt.md".text = builtins.readFile ./create-readme.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/memory-load.prompt.md".text = builtins.readFile ./memory-load.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/memory-save.prompt.md".text = builtins.readFile ./memory-save.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/offboard.prompt.md".text = builtins.readFile ./offboard.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/onboard.prompt.md".text = builtins.readFile ./onboard.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/orientate.prompt.md".text = builtins.readFile ./orientate.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/plan-code.prompt.md".text = builtins.readFile ./plan-code.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/plan-docs.prompt.md".text = builtins.readFile ./plan-docs.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/review-code.prompt.md".text = builtins.readFile ./review-code.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/review-naming.prompt.md".text = builtins.readFile ./review-naming.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/review-performance.prompt.md".text = builtins.readFile ./review-performance.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/review-pull-request-feedback.prompt.md".text = builtins.readFile ./review-pull-request-feedback.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/review-tests.prompt.md".text = builtins.readFile ./review-tests.prompt.md;
      "${config.xdg.configHome}/Code/User/prompts/update-docs.prompt.md".text = builtins.readFile ./update-docs.prompt.md;
    };
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      bash-language-server
      unstable.github-mcp-server
      go
      gopls
      luaformatter
      luajit
      lua-language-server
      unstable.mcp-nixos
      nil
      nixfmt-rfc-style
      nodePackages.prettier
      nodejs_24
      python3Full
      uv
      shellcheck
      shfmt
      stylua
    ];
  };

  programs = {
    vscode = {
      enable = true;
      profiles.default = {
        enableExtensionUpdateCheck = false;
        enableUpdateCheck = false;
        userSettings = {
          "chat.mcp.autostart" = "newAndOutdated";
          "chat.mcp.discovery.enabled" = true;
          "chat.mcp.enabled" = true;
          "cline.chromeExecutablePath" = "/run/current-system/sw/bin/brave";
          "cSpell.userWords" = [
            "distro"
            "distrobox"
            "distroboxrc"
            "distros"
            "dkms"
            "Flatpak"
            "gphoto"
            "Keyer"
            "libnvidia"
            "localuser"
            "NVENC"
            "Pango"
            "Pipewire"
            "Quickemu"
            "quickget"
            "quickreport"
            "reqwest"
            "RIST"
            "RTMP"
            "RTSP"
            "shellcheck"
            "Syncthing"
            "ublue"
            "Vulkan"
            "Wimpress"
            "xhost"
            "Xwayland"
          ];
          "dart.updateDevTools" = false;
          "dart.checkForSdkUpdates" = false;
          "editor.bracketPairColorization.independentColorPoolPerBracketType" = true;
          "editor.fontSize" = 16;
          "editor.fontFamily" = "FiraCode Nerd Font Mono";
          "editor.fontLigatures" = true;
          # fontWeight:
          # 300 - Light
          # 400 - Regular
          # 450 - Retina (only works with FiraCode-VF.ttf installed, see below when using separated font files)
          # 500 - Medium
          # 600 - Bold
          "editor.fontWeight" = "400";
          "editor.guides.bracketPairs" = true;
          "editor.guides.bracketPairsHorizontal" = true;
          "editor.inlineSuggest.enabled" = true;
          "editor.renderWhitespace" = "all";
          "editor.rulers" = [ 80 88 ];
          "editor.semanticHighlighting.enabled" = true;
          "explorer.confirmDragAndDrop" = false;
          "extensions.ignoreRecommendations" = true;
          "[dart]"."editor.formatOnSave" = true;
          "[dart]"."editor.formatOnType" = true;
          "[dart]"."editor.rulers" = [ 80 ];
          "[dart]"."editor.selectionHighlight" = false;
          "[dart]"."editor.suggest.snippetsPreventQuickSuggestions" = false;
          "[dart]"."editor.suggestSelection" = "first";
          "[dart]"."editor.tabCompletion" = "onlySnippets";
          "[dart]"."editor.wordBasedSuggestions" = "off";
          "[dockerfile]"."editor.quickSuggestions.strings" = true;
          "[lua]"."editor.defaultFormatter" = "JohnnyMorganz.stylua";
          "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
          "[nix]"."editor.formatOnSave" = true;
          "[nix]"."editor.tabSize" = 2;
          "[python]"."editor.formatOnType" = true;
          "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "git.openRepositoryInParentFolders" = "always";
          "github.copilot.chat.agent.thinkingTool" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "githubPullRequests.pullBranch" = "never";
          "markdown.preview.breaks" = true;
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nil";
          "nix.serverSettings" = {
            "nil" = {
              "formatting" = {
                "command" = [ "nixfmt" ];
              };
            };
          };
          "partialDiff.enableTelemetry" = false;
          "projectManager.git" = {
            baseFolders = [
              "~/Chainguard"
              "~/Development"
              "~/Websites"
              "~/Zero"
            ];
            maxDepthRecursion = 5;
          };
          "redhat.telemetry.enabled" = false;
          "security.workspace.trust.untrustedFiles" = "open";
          "shellcheck.run" = "onSave";
          "shellformat.useEditorConfig" = true;
          "telemetry.feedback.enabled" = false;
          "telemetry.telemetryLevel" = "off";
          "terminal.integrated.fontSize" = 16;
          "terminal.integrated.fontFamily" = "FiraCode Nerd Font Mono";
          "terminal.integrated.fontWeight" = "400";
          "terminal.integrated.fontWeightBold" = "600";
          "terminal.integrated.scrollback" = 10240;
          "terminal.integrated.copyOnSelection" = true;
          "terminal.integrated.cursorBlinking" = true;
          "update.mode" = "none";
          "vsicons.dontShowNewVersionMessage" = true;
          "workbench.tree.indent" = 20;
          "workbench.startupEditor" = "none";
          "workbench.editor.empty.hint" = "hidden";
          #"workbench.preferredLightColorTheme": "Catppuccin Frappé",
          #"workbench.iconTheme": "catppuccin-mocha",
          "github.copilot.chat.commitMessageGeneration.instructions.text" = ''
            You will act as a git commit message generator. When receiving a git diff, you will ONLY output the commit message itself, nothing else. No explanations, no questions, no additional comments.

            Commits must follow the Conventional Commits 1.0.0 specification and be further refined using the rules outlined below.

            The commit message must include the following fields: "type", "description", "body".
            The commit message must be in the format:
            <type>([optional scope]): <description>

            [body]

            [optional footer(s)]

            - "type": Choose one of the following:
              - feat: MUST be used when commits that introduce new features or functionalities to the project (this correlates with MINOR in Semantic Versioning)
              - fix: MUST be used when commits address bug fixes or resolve issues in the project (this correlates with PATCH in Semantic Versioning)
              - types other than feat: and fix: can be used in your commit messages:
                - build: Used when a commit affects the build system or external dependencies. It includes changes to build scripts, build configurations, or build tools used in the project
                - chore: Typically used for routine or miscellaneous tasks related to the project, such as code reformatting, updating dependencies, or making general project maintenance
                - ci: CI stands for continuous integration. This type is used for changes to the project's continuous integration or deployment configurations, scripts, or infrastructure
                - docs: Documentation plays a vital role in software projects. The docs type is used for commits that update or add documentation, including readme files, API documentation, user guides or code comments that act as documentation
                - i18n: This type is used for commits that involve changes related to internationalization or localization. It includes changes to localization files, translations, or internationalization-related configurations.
                - perf: Short for performance, this type is used when a commit improves the performance of the code or optimizes certain functionalities
                - refactor: Commits typed as refactor involve making changes to the codebase that neither fix a bug nor add a new feature. Refactoring aims to improve code structure, organization, or efficiency without changing external behavior
                - revert: Commits typed as revert are used to undo previous commits. They are typically used to reverse changes made in previous commits
                - style: The style type is used for commits that focus on code style changes, such as formatting, indentation, or whitespace modifications. These commits do not affect the functionality of the code but improve its readability and maintainability
                - test: Used for changes that add or modify test cases, test frameworks, or other related testing infrastructure.
            - "description": A very brief summary line (max 72 characters). Do not end with a period. Use imperative mood (e.g., 'add feature' not 'added feature').
            - "body": A more detailed explanation of the changes, focusing on what problem this commit solves and why this change was necessary. Small changes can be a concise, specific sentence. Larger changes should be a bulleted list of concise, specific changes. Include optional footers like BREAKING CHANGE here.

            Guidelines for writing the commit message:
            - The <description> must be in English
            - The [optional scope] must be in English
            - The <description> must be imperative mood
            - The <description> must avoid capitalization
            - The <description> will not have a period at the end
            - The <description> will have a maximum of 72 characters including any spaces or special characters
            - The <description> must avoid using the <type> as the first word
            - Follow the <description> with a blank line, then the [body].
            - The [body] must be in English
            - The [body] should provide a more detailed explanation. Small changes as one sentence, larger changes as a bulleted list.
            - The [body] should explain what and why
            - The [body] will be objective
            - Bullet points in the [body] start with "-"
            - The [optional footer(s)] can be used for things like referencing issues or indicating breaking changes.

            Specification for Conventional Commits:
            - Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space.
            - A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
            - A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., fix: array parsing issue when multiple spaces were contained in string.
            - A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
            - A commit body is free-form and MAY consist of any number of newline separated paragraphs.
            - One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by either a :<space> or <space># separator, followed by a string value (this is inspired by the git trailer convention).
            - A footer's token MUST use - in place of whitespace characters, e.g., Acked-by (this helps differentiate the footer section from a multi-paragraph body). An exception is made for BREAKING CHANGE, which MAY also be used as a token.
            - A footer's value MAY contain spaces and newlines, and parsing MUST terminate when the next valid footer token/separator pair is observed.
            - Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer.
            - If included as a footer, a breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon, space, and description, e.g., BREAKING CHANGE: environment variables now take precedence over config files.
            - If included in the type/scope prefix, breaking changes MUST be indicated by a ! immediately before the :. If ! is used, BREAKING CHANGE: MAY be omitted from the footer section, and the commit description SHALL be used to describe the breaking change.
            - The units of information that make up Conventional Commits MUST NOT be treated as case sensitive by implementors, with the exception of BREAKING CHANGE which MUST be uppercase.
            - BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.
          '';
        };
        extensions =
          with pkgs;
          [
            vscode-marketplace.aaron-bond.better-comments
            vscode-marketplace.alefragnani.project-manager
            vscode-marketplace.alexgb.nelua
            vscode-marketplace.anthropic.claude-code
            vscode-marketplace.automatalabs.copilot-mcp
            vscode-marketplace.bmalehorn.shell-syntax
            vscode-marketplace.bmalehorn.vscode-fish
            vscode-marketplace.budparr.language-hugo-vscode
            vscode-marketplace.catppuccin.catppuccin-vsc-icons
            vscode-marketplace.codezombiech.gitignore
            vscode-marketplace.coolbear.systemd-unit-file
            vscode-marketplace.dart-code.dart-code
            vscode-marketplace.dart-code.flutter
            vscode-marketplace.dotjoshjohnson.xml
            vscode-marketplace.editorconfig.editorconfig
            vscode-marketplace.eliostruyf.vscode-front-matter
            vscode-marketplace.esbenp.prettier-vscode
            vscode-marketplace.evan-buss.font-switcher
            vscode-marketplace.fill-labs.dependi
            vscode-marketplace.foxundermoon.shell-format
            vscode-marketplace.github.copilot
            vscode-marketplace.github.copilot-chat
            vscode-marketplace.github.vscode-github-actions
            vscode-marketplace.github.vscode-pull-request-github
            vscode-marketplace.golang.go
            vscode-marketplace.griimick.vhs
            vscode-marketplace.hashicorp.terraform
            vscode-marketplace.hoovercj.vscode-power-mode
            vscode-marketplace.ismoh-games.second-local-lua-debugger-vscode
            vscode-marketplace.jdemille.debian-control-vscode
            vscode-marketplace.jeff-hykin.better-csv-syntax
            vscode-marketplace.jeff-hykin.better-dockerfile-syntax
            vscode-marketplace.jeff-hykin.better-nix-syntax
            vscode-marketplace.jeff-hykin.better-shellscript-syntax
            vscode-marketplace.jeff-hykin.polacode-2019
            vscode-marketplace.jeroen-meijer.pubspec-assist
            vscode-marketplace.jnoortheen.nix-ide
            vscode-marketplace.johnnymorganz.stylua
            vscode-marketplace.marp-team.marp-vscode
            vscode-marketplace.mechatroner.rainbow-csv
            vscode-marketplace.mkhl.direnv
            vscode-marketplace.ms-python.debugpy
            vscode-marketplace.ms-python.python
            vscode-marketplace.ms-python.vscode-pylance
            vscode-marketplace.ms-vscode.cmake-tools
            vscode-marketplace.ms-vscode.hexeditor
            vscode-extensions.ms-vscode-remote.vscode-remote-extensionpack
            vscode-marketplace.nefrob.vscode-just-syntax
            vscode-marketplace.nico-castell.linux-desktop-file
            vscode-marketplace.pixelbyte-studios.pixelbyte-love2d
            vscode-marketplace.pkief.material-product-icons
            vscode-marketplace.prince781.vala
            vscode-marketplace.pollywoggames.pico8-ls
            vscode-marketplace.redhat.vscode-yaml
            vscode-marketplace.rogalmic.bash-debug
            vscode-marketplace.rust-lang.rust-analyzer
            vscode-marketplace.ryu1kn.partial-diff
            vscode-marketplace.s3anmorrow.openwithkraken
            vscode-marketplace.sanjulaganepola.github-local-actions
            vscode-marketplace.saoudrizwan.claude-dev
            vscode-marketplace.slevesque.shader
            vscode-marketplace.streetsidesoftware.code-spell-checker
            vscode-marketplace.tamasfe.even-better-toml
            vscode-marketplace.timonwong.shellcheck
            vscode-marketplace.trond-snekvik.simple-rst
            vscode-marketplace.twxs.cmake
            vscode-marketplace.tobiashochguertel.just-formatter
            vscode-marketplace.unifiedjs.vscode-mdx
            vscode-marketplace.viktorzetterstrom.non-breaking-space-highlighter
            vscode-marketplace.vscode-icons-team.vscode-icons
            vscode-marketplace.xyc.vscode-mdx-preview
            vscode-marketplace.yinfei.luahelper
            vscode-marketplace.yzhang.markdown-all-in-one
          ]
          ++ lib.optionals isLinux [
            vscode-extensions.ms-vscode.cpptools-extension-pack
            vscode-extensions.ms-vsliveshare.vsliveshare
            vscode-extensions.vadimcn.vscode-lldb
          ];
        };
      mutableExtensionsDir = true;
      package = pkgs.unstable.vscode;
    };
  };
  services.vscode-server.enable = true;
}
