{
  config,
  pkgs,
  ...
}:
{
  # Enable the Catppuccin theme
  catppuccin = {
    gh-dash.enable = config.programs.gh.extensions.gh-dash;
    gitui.enable = config.programs.gitui.enable;
  };

  home = {
    file = {
      "${config.xdg.configHome}/fish/functions/h.fish".text = builtins.readFile ../../../_mixins/configs/h.fish;
    };

    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages =
      with pkgs;
      [
        unstable.apko # Declarative container images
        chainctl # Chainguard Platform CLI
        crane # Container registry client
        dive # Explore container images
        difftastic # Modern Unix `diff`
        ghbackup # Backup GitHub repositories
        ghorg # Clone all repositories in a GitHub organization
        git-igitt # git log/graph
        gk-cli # GitKraken CLI
        google-cloud-sdk # Google Cloud CLI
        unstable.grype # Vulnerability scanner
        h # autojump for git projects
        kind # Kubernetes in Docker
        unstable.melange # Declarative package manager
        onefetch # fetch git project info
        quilt # patch manager
        terraform # Infrastructure as code tool
        tokei # Modern Unix `wc` for code
        unstable.syft # SBOM scanner
      ];
  };

  programs = {
    gh = {
      enable = true;
      # TODO: Package https://github.com/DevAtDawn/gh-fish
      extensions = with pkgs; [
        gh-copilot
        gh-dash
        gh-markdown-preview
        gh-notify
      ];
      settings = {
        editor = "micro";
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
    git = {
      enable = true;
      aliases = {
        ci = "commit";
        cl = "clone";
        co = "checkout";
        purr = "pull --rebase";
        dlog = "!f() { GIT_EXTERNAL_DIFF=difft git log -p --ext-diff $@; }; f";
        dshow = "!f() { GIT_EXTERNAL_DIFF=difft git show --ext-diff $@; }; f";
        fucked = "reset --hard";
        graph = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
      difftastic = {
        display = "side-by-side-show-both";
        enable = true;
      };
      extraConfig = {
        advice = {
          statusHints = false;
        };
        color = {
          branch = false;
          diff = false;
          interactive = true;
          log = false;
          status = true;
          ui = false;
        };
        core = {
          pager = "bat";
        };
        push = {
          default = "matching";
        };
        pull = {
          rebase = false;
        };
        init = {
          defaultBranch = "main";
        };
      };
      ignores = [
        "*.log"
        "*.out"
        ".DS_Store"
        "bin/"
        "dist/"
        "result"
      ];
    };
    gitui = {
      enable = true;
    };
  };
  # https://dl.thalheim.io/
  sops = {
    secrets = {
      act-env = {
        path = "${config.home.homeDirectory}/.config/act/secrets";
        sopsFile = ../../../../secrets/act.yaml;
        mode = "0660";
      };
      gh_token = { };
    };
  };
}
