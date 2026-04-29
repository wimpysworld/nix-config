{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # https://github.com/numtide/llm-agents.nix
  claudePackage =
    if host.is.linux then
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    else if host.is.darwin then
      pkgs.unstable.claude-code
    else
      pkgs.claude-code;

  # Import shared MCP server definitions
  mcpServerDefs = import ../mcp/servers.nix { inherit config pkgs; };

  claudeAbsolutePattern = path: "//${lib.removePrefix "/" path}";
  claudeWorkspaceRoots = [
    "${config.home.homeDirectory}/Chainguard"
    "${config.home.homeDirectory}/Development"
    "${config.home.homeDirectory}/Volatile"
    "${config.home.homeDirectory}/Zero"
    "/tmp"
  ];
  claudeWorkspaceEditRules = map (
    path: "Edit(${claudeAbsolutePattern "${path}/**"})"
  ) claudeWorkspaceRoots;

  # Patch ccstatusline to accept null values for the five_hour and seven_day
  # fields in the Anthropic usage API response. The API returns null for these
  # fields when no usage data is available, but ccstatusline's Zod schema uses
  # `.optional()` rather than `.nullish()` for the outer object wrapper.
  # `.optional()` permits `undefined` but rejects `null`, so safeParse fails
  # and the session-usage and weekly-usage widgets render "[Parse Error]"
  # indefinitely. Replacing `.optional()` with `.nullish()` on the outer object
  # accepts both undefined and null, matching the actual API contract.
  #
  # v2.2.0 expanded the schema to include resets_at alongside utilization,
  # so the match pattern covers the full three-line block for each field.
  ccstatuslinePatched =
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ccstatusline.overrideAttrs
      (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.perl ];
        postInstall = (old.postInstall or "") + ''
          # Patch five_hour and seven_day outer object wrappers from .optional()
          # to .nullish() so that the Zod schema accepts null (not just undefined)
          # when the Anthropic API returns null for those fields. The v2.2.0
          # schema spans multiple lines; perl -0pe slurps the whole file so
          # [^}]+ matches across newlines inside the object literal.
          perl -i -0pe \
            's/(five_hour: exports_external\.object\(\{[^}]+\}\))\.optional\(\),/$1.nullish(),/s;
             s/(seven_day: exports_external\.object\(\{[^}]+\}\))\.optional\(\),/$1.nullish(),/s' \
            "$out/bin/ccstatusline"
        '';
      });

  # Permission lists for Claude Code
  # Format: "Bash(command:*)" for prefix matching, "Bash(command)" for exact
  bashAllow = [
    # Shell - read-only and low-risk
    "Bash(ls:*)"
    "Bash(cat:*)"
    "Bash(head:*)"
    "Bash(tail:*)"
    "Bash(wc:*)"
    "Bash(file:*)"
    "Bash(tree:*)"
    "Bash(pwd)"
    "Bash(which:*)"
    "Bash(type:*)"
    "Bash(env)"
    "Bash(fd:*)"
    "Bash(rg:*)"
    "Bash(grep:*)"
    "Bash(egrep:*)"
    "Bash(fgrep:*)"
    "Bash(whoami)"
    "Bash(hostname)"
    "Bash(uname:*)"
    "Bash(df:*)"
    "Bash(free:*)"
    "Bash(ps:*)"
    "Bash(top -b:*)"
    "Bash(uptime)"
    "Bash(date)"
    "Bash(lscpu)"
    "Bash(lsblk)"
    "Bash(lsusb)"
    "Bash(lspci)"
    "Bash(id)"
    "Bash(groups)"
    "Bash(printenv:*)"
    "Bash(basename:*)"
    "Bash(dirname:*)"
    "Bash(realpath:*)"
    "Bash(stat:*)"
    "Bash(du:*)"
    "Bash(sort:*)"
    "Bash(uniq:*)"
    "Bash(cut:*)"
    "Bash(awk:*)"
    "Bash(diff:*)"
    "Bash(cmp:*)"
    "Bash(less:*)"
    "Bash(more:*)"
    "Bash(tr:*)"
    "Bash(tac:*)"
    "Bash(rev:*)"
    "Bash(seq:*)"
    "Bash(md5sum:*)"
    "Bash(sha256sum:*)"
    "Bash(shasum:*)"
    "Bash(jq:*)"
    "Bash(yq:*)"
    "Bash(bc:*)"
    "Bash(man:*)"
    "Bash(tldr:*)"
    "Bash(strings:*)"

    # Text processing - additional
    "Bash(column:*)"
    "Bash(fold:*)"
    "Bash(nl:*)"
    "Bash(pr:*)"
    "Bash(expand:*)"
    "Bash(unexpand:*)"
    "Bash(paste:*)"
    "Bash(join:*)"
    "Bash(comm:*)"

    # Archive inspection (read-only)
    "Bash(tar -t:*)"
    "Bash(tar --list:*)"
    "Bash(unzip -l:*)"
    "Bash(zipinfo:*)"
    "Bash(7z l:*)"
    "Bash(zcat:*)"
    "Bash(bzcat:*)"
    "Bash(xzcat:*)"
    "Bash(zless:*)"
    "Bash(bzless:*)"
    "Bash(xzless:*)"

    # Network inspection (read-only)
    "Bash(ip addr)"
    "Bash(ip addr show:*)"
    "Bash(ip link show:*)"
    "Bash(ip route show:*)"
    "Bash(ss -t:*)"
    "Bash(ss -u:*)"
    "Bash(ss -l:*)"
    "Bash(netstat -t:*)"
    "Bash(netstat -l:*)"
    "Bash(ping -c:*)"
    "Bash(traceroute:*)"
    "Bash(dig:*)"
    "Bash(host:*)"
    "Bash(nslookup:*)"

    # Process inspection
    "Bash(pgrep:*)"
    "Bash(pidof:*)"
    "Bash(pstree:*)"
    "Bash(lsof -p:*)"
    "Bash(lsof:*)"

    # Alternative file viewers
    "Bash(bat:*)"
    "Bash(most:*)"

    # Agent/task delegation and skills
    "Agent"
    "Skill"
    "Task"

    # Development helpers
    "Bash(xxd:*)"
    "Bash(hexdump:*)"
    "Bash(od:*)"
    "Bash(base64:*)"
    "Bash(base32:*)"
    "Bash(shellcheck:*)"
    "Bash(shfmt --diff:*)"
    "Bash(shfmt -d:*)"
    "Bash(luacheck:*)"

    # Systemd - read-only status and log queries
    "Bash(systemctl --version)"
    "Bash(systemctl status:*)"
    "Bash(systemctl is-active:*)"
    "Bash(systemctl is-enabled:*)"
    "Bash(systemctl is-failed:*)"
    "Bash(systemctl list-units:*)"
    "Bash(systemctl list-unit-files:*)"
    "Bash(systemctl show:*)"
    "Bash(systemctl cat:*)"
    "Bash(systemctl list-dependencies:*)"
    "Bash(systemctl list-jobs:*)"
    "Bash(journalctl:*)"
    "Bash(systemd-analyze:*)"
    "Bash(hostnamectl:*)"
    "Bash(timedatectl:*)"
    "Bash(loginctl:*)"
    "Bash(localectl:*)"
    "Bash(networkctl:*)"
    "Bash(resolvectl:*)"
    "Bash(busctl:*)"
    "Bash(coredumpctl:*)"

    # Container - read-only queries
    "Bash(docker --version)"
    "Bash(docker ps:*)"
    "Bash(docker images:*)"
    "Bash(docker logs:*)"
    "Bash(docker inspect:*)"
    "Bash(docker info)"
    "Bash(docker stats:*)"
    "Bash(docker network ls:*)"
    "Bash(docker volume ls:*)"
    "Bash(docker-compose --version)"
    "Bash(docker compose --version)"

    # Build tools - version checks and info
    "Bash(autoconf --version)"
    "Bash(automake --version)"
    "Bash(make --version)"
    "Bash(make -n:*)"
    "Bash(cmake --version)"
    "Bash(cmake -E capabilities)"
    "Bash(meson --version)"
    "Bash(ninja --version)"
    "Bash(clang --version)"
    "Bash(clang++ --version)"
    "Bash(clang-tidy --version)"
    "Bash(clang-format --version)"
    "Bash(clangd --version)"
    "Bash(gcc --version)"
    "Bash(g++ --version)"
    "Bash(ldd:*)"
    "Bash(pkg-config:*)"
    "Bash(pkgconf:*)"
    "Bash(ar --version)"
    "Bash(ranlib --version)"
    "Bash(objdump:*)"
    "Bash(nm:*)"
    "Bash(readelf:*)"

    # FFmpeg - info and probing
    "Bash(ffmpeg -version)"
    "Bash(ffmpeg -formats)"
    "Bash(ffmpeg -codecs)"
    "Bash(ffmpeg -encoders)"
    "Bash(ffmpeg -decoders)"
    "Bash(ffmpeg -bsfs)"
    "Bash(ffmpeg -protocols)"
    "Bash(ffmpeg -pix_fmts)"
    "Bash(ffmpeg -layouts)"
    "Bash(ffmpeg -sample_fmts)"
    "Bash(ffmpeg -filters)"
    "Bash(ffmpeg -loglevel:*)"
    "Bash(ffmpeg -hwaccels)"
    "Bash(ffprobe:*)"

    # GitHub - read-only queries
    "Bash(gh --version)"
    "Bash(gh help)"
    "Bash(gh help:*)"
    "Bash(gh repo view:*)"
    "Bash(gh pr view:*)"
    "Bash(gh pr list:*)"
    "Bash(gh issue view:*)"
    "Bash(gh issue list:*)"
    "Bash(gh status)"
    "Bash(gh api:*)"

    # Git - read-only queries
    "Bash(git status:*)"
    "Bash(git diff:*)"
    "Bash(git log:*)"
    "Bash(git branch:*)"
    "Bash(git remote:*)"
    "Bash(git show:*)"
    "Bash(git stash list)"
    "Bash(git tag:*)"
    "Bash(git worktree list)"
    "Bash(git config --list:*)"
    "Bash(git config --get:*)"
    "Bash(git reflog:*)"
    "Bash(git rev-parse:*)"
    "Bash(git describe:*)"
    "Bash(git shortlog:*)"
    "Bash(git blame:*)"
    "Bash(git ls-files:*)"
    "Bash(git ls-tree:*)"
    "Bash(git grep:*)"

    # Hugo - info only
    "Bash(hugo version)"
    "Bash(hugo env)"

    # ImageMagick - info and metadata
    "Bash(identify:*)"
    "Bash(convert --version)"
    "Bash(magick --version)"
    "Bash(magick identify:*)"
    "Bash(compare --version)"
    "Bash(composite --version)"
    "Bash(mogrify --version)"

    # Nix - info and evaluation
    "Bash(nix --version)"
    "Bash(nix flake show:*)"
    "Bash(nix flake check:*)"
    "Bash(nix flake metadata:*)"
    "Bash(nix flake info:*)"
    "Bash(nix eval:*)"
    "Bash(nix search:*)"
    "Bash(nix path-info:*)"
    "Bash(nix why-depends:*)"
    "Bash(nix derivation show:*)"
    "Bash(nix store ls:*)"
    "Bash(nix hash:*)"
    "Bash(nix repl:*)"
    "Bash(nix log:*)"
    "Bash(nix show-config:*)"
    "Bash(nix doctor)"
    "Bash(nix store verify:*)"
    "Bash(nix-store --query:*)"
    "Bash(nix-store -q:*)"
    "Bash(nix-instantiate)"
    "Bash(nix-instantiate:*)"
    "Bash(nixfmt)"
    "Bash(nixfmt:*)"
    "Bash(statix:*)"
    "Bash(deadnix:*)"
    "Bash(alejandra:*)"

    # Go - info and static analysis
    "Bash(go version)"
    "Bash(go env:*)"
    "Bash(go list:*)"
    "Bash(go vet:*)"
    "Bash(go doc:*)"
    "Bash(go mod graph)"
    "Bash(go mod why:*)"
    "Bash(ineffassign)"
    "Bash(ineffassign:*)"
    "Bash(actionlist)"
    "Bash(actionlist:*)"
    "Bash(golangci-lint run:*)"
    "Bash(golangci-lint --version)"
    "Bash(golangci-lint linters)"
    "Bash(gofumpt --version)"
    "Bash(gofumpt -l:*)"
    "Bash(govulncheck)"
    "Bash(govulncheck:*)"

    # JavaScript/TypeScript - info and type checking
    "Bash(node --version)"
    "Bash(npm --version)"
    "Bash(pnpm --version)"
    "Bash(npm ls:*)"
    "Bash(npm outdated:*)"
    "Bash(npm view:*)"
    "Bash(npm info:*)"
    "Bash(npx --version)"
    "Bash(tsc --version)"
    "Bash(tsc --noEmit:*)"

    # Just - listing only
    "Bash(just --version)"
    "Bash(just --list)"
    "Bash(just -l)"
    "Bash(just --summary)"
    "Bash(just eval)"
    "Bash(just build)"

    # Lua - info only
    "Bash(lua -v)"
    "Bash(love --version)"

    # Rust - info and static analysis
    "Bash(cargo --version)"
    "Bash(cargo check:*)"
    "Bash(cargo clippy:*)"
    "Bash(cargo doc:*)"
    "Bash(cargo tree:*)"
    "Bash(cargo metadata:*)"
    "Bash(cargo fmt --check:*)"
    "Bash(rustc --version)"
    "Bash(rustup --version)"
    "Bash(rustup show:*)"
    "Bash(rustup target list:*)"
    "Bash(rustup component list:*)"

    # Python - info and read-only
    "Bash(python --version)"
    "Bash(python3 --version)"
    "Bash(pip --version)"
    "Bash(pip list:*)"
    "Bash(pip show:*)"
    "Bash(pip freeze:*)"
    "Bash(pip check)"
    "Bash(pytest --version)"
    "Bash(python -m pytest --collect-only:*)"
    "Bash(mypy --version)"
    "Bash(ruff --version)"
    "Bash(ruff check:*)"
    "Bash(uv --version)"
    "Bash(uv pip list:*)"

    # Svelte - info
    "Bash(svelte-check --help)"

    # Wails - info only
    "Bash(wails --version)"
    "Bash(wails doctor)"

    # Cloudflare - info only
    "Bash(wrangler --version)"
    "Bash(wrangler whoami)"
  ];

  bashAsk = [
    # Shell - file modification or redirection risk
    "Bash(xdg-open:*)"
    "Bash(sed:*)"
    "Bash(sd:*)"
    "Bash(mkdir:*)"
    "Bash(touch:*)"
    "Bash(mv:*)"
    "Bash(cp:*)"
    "Bash(tee:*)"
    "Bash(echo:*)"
    "Bash(printf:*)"
    "Bash(curl:*)"
    "Bash(wget:*)"
    "Bash(chmod:*)"
    "Bash(chown:*)"
    "Bash(kill:*)"
    "Bash(pkill:*)"
    "Bash(ln:*)" # Symlink creation - can overwrite files

    # Systemd - service state modifications
    "Bash(systemctl start:*)"
    "Bash(systemctl stop:*)"
    "Bash(systemctl restart:*)"
    "Bash(systemctl reload:*)"
    "Bash(systemctl enable:*)"
    "Bash(systemctl disable:*)"
    "Bash(systemctl mask:*)"
    "Bash(systemctl unmask:*)"
    "Bash(systemctl daemon-reload)"
    "Bash(systemctl edit:*)"

    # Container - operations
    "Bash(docker build:*)"
    "Bash(docker run:*)"
    "Bash(docker exec:*)"
    "Bash(docker stop:*)"
    "Bash(docker start:*)"
    "Bash(docker-compose up:*)"
    "Bash(docker-compose down:*)"
    "Bash(docker compose up:*)"
    "Bash(docker compose down:*)"
    "Bash(docker pull:*)"
    "Bash(docker push:*)"

    # Build tools - configuration and builds
    "Bash(./configure:*)"
    "Bash(configure:*)"
    "Bash(autoreconf:*)"
    "Bash(autoconf:*)"
    "Bash(automake:*)"
    "Bash(make:*)"
    "Bash(cmake:*)"
    "Bash(meson:*)"
    "Bash(ninja:*)"
    "Bash(clang:*)"
    "Bash(clang++:*)"
    "Bash(gcc:*)"
    "Bash(g++:*)"
    "Bash(ar:*)"
    "Bash(ranlib:*)"
    "Bash(clang-tidy:*)"
    "Bash(clang-format:*)"

    # FFmpeg - file processing
    "Bash(ffmpeg:*)"

    # GitHub - state modifications
    "Bash(gh pr create:*)"
    "Bash(gh pr merge:*)"
    "Bash(gh pr checkout:*)"
    "Bash(gh issue create:*)"
    "Bash(gh release create:*)"
    "Bash(gh repo create:*)"
    "Bash(gh repo clone:*)"

    # Git - state modifications
    "Bash(git add:*)"
    "Bash(git commit:*)"
    "Bash(git push:*)"
    "Bash(git pull:*)"
    "Bash(git fetch:*)"
    "Bash(git checkout:*)"
    "Bash(git switch:*)"
    "Bash(git merge:*)"
    "Bash(git rebase:*)"
    "Bash(git stash:*)"
    "Bash(git restore:*)"
    "Bash(git cherry-pick:*)"
    "Bash(git worktree:*)"

    # Hugo - builds and server
    "Bash(hugo:*)"

    # ImageMagick - file processing
    "Bash(convert:*)"
    "Bash(magick:*)"
    "Bash(mogrify:*)"
    "Bash(compare:*)"
    "Bash(composite:*)"

    # Nix - builds and environment
    "Bash(nix build:*)"
    "Bash(nix develop:*)"
    "Bash(nix-shell:*)"
    "Bash(nix flake update:*)"
    "Bash(nix-env:*)"
    "Bash(home-manager switch:*)"
    "Bash(nixos-rebuild:*)"
    "Bash(darwin-rebuild:*)" # macOS system rebuild (nix-darwin)

    # Go - builds and code execution
    "Bash(go build:*)"
    "Bash(go run:*)"
    "Bash(go test:*)"
    "Bash(go generate:*)"
    "Bash(go get:*)"
    "Bash(go mod tidy)"
    "Bash(go install:*)"

    # JavaScript/TypeScript - installs and execution
    "Bash(npm install:*)"
    "Bash(npm run:*)"
    "Bash(npm test:*)"
    "Bash(npm publish:*)"
    "Bash(pnpm install:*)"
    "Bash(pnpm run:*)"
    "Bash(yarn add:*)"
    "Bash(yarn install:*)"
    "Bash(vite:*)"

    # Just - recipe execution
    "Bash(just:*)"

    # Lua - execution
    "Bash(lua:*)"
    "Bash(love:*)"
    "Bash(luarocks install:*)"
    "Bash(luarocks remove:*)"

    # Rust - builds and code execution
    "Bash(cargo build:*)"
    "Bash(cargo test:*)"
    "Bash(cargo run:*)"
    "Bash(cargo install:*)"
    "Bash(cargo publish:*)"
    "Bash(cargo update:*)"
    "Bash(rustup update:*)"
    "Bash(rustup default:*)"

    # Python - installs and execution
    "Bash(pip install:*)"
    "Bash(pip uninstall:*)"
    "Bash(python:*)"
    "Bash(python3:*)"
    "Bash(pytest:*)"
    "Bash(mypy:*)"
    "Bash(ruff:*)"
    "Bash(uv pip install:*)"
    "Bash(uv sync:*)"
    "Bash(uv run:*)"

    # Svelte - builds and type checking
    "Bash(svelte-kit sync:*)"
    "Bash(svelte-check:*)"
    "Bash(svelte-kit build:*)"

    # Wails - builds and dev server
    "Bash(wails build:*)"
    "Bash(wails dev:*)"
    "Bash(wails init:*)"

    # Cloudflare - development and deployment
    "Bash(wrangler dev:*)"
    "Bash(wrangler deploy:*)"
    "Bash(wrangler publish:*)"
    "Bash(wrangler secret:*)"
    "Bash(wrangler kv:*)"
    "Bash(wrangler r2:*)"
    "Bash(wrangler d1:*)"
  ];

  bashAskDestructive = [
    # Shell - destructive file operations (supervised deletion)
    "Bash(rm:*)"
    "Bash(rmdir:*)"
  ];

  bashDeny = [
    # Shell - privilege escalation and secure deletion
    "Bash(sudo:*)"
    "Bash(shred:*)"
    "Bash(wipe:*)"
    "Bash(srm:*)"
    "Bash(truncate:*)"

    # System modification
    "Bash(sysctl:*)"
    "Bash(modprobe:*)"
    "Bash(insmod:*)"
    "Bash(rmmod:*)"

    # Boot/firmware
    "Bash(grub-install:*)"
    "Bash(update-grub:*)"
    "Bash(efibootmgr:*)"

    # Disk operations
    "Bash(fdisk:*)"
    "Bash(parted:*)"
    "Bash(gparted:*)"
    "Bash(mkfs:*)"
    "Bash(mkswap:*)"
    "Bash(swapon:*)"
    "Bash(swapoff:*)"
    "Bash(mount:*)"
    "Bash(umount:*)"
    "Bash(dd:*)" # Disk copy utility - extremely dangerous, can destroy disks

    # Subshell execution bypasses
    "Bash(bash -c:*)"
    "Bash(sh -c:*)"
    "Bash(fish -c:*)"
    "Bash(zsh -c:*)"
    "Bash(dash -c:*)"

    # Direct code execution via interpreters
    "Bash(python -c:*)"
    "Bash(python3 -c:*)"
    "Bash(python2 -c:*)"
    "Bash(node -e:*)"
    "Bash(node --eval:*)"
    "Bash(perl -e:*)"
    "Bash(ruby -e:*)"
    "Bash(lua -e:*)"
    "Bash(php -r:*)"

    # Systemd - power management
    "Bash(systemctl poweroff:*)"
    "Bash(systemctl reboot:*)"
    "Bash(systemctl halt:*)"
    "Bash(systemctl suspend:*)"
    "Bash(systemctl hibernate:*)"

    # Container - mass destruction
    "Bash(docker system prune:*)"
    "Bash(docker volume prune:*)"
    "Bash(docker container prune:*)"
    "Bash(docker image prune:*)"

    # GitHub - destructive operations
    "Bash(gh repo delete:*)"

    # Git - history rewriting / destructive
    "Bash(git push --force:*)"
    "Bash(git push -f:*)"
    "Bash(git reset --hard:*)"
    "Bash(git clean:*)"
    "Bash(git filter-branch:*)"

    # Nix - garbage collection
    "Bash(nix-collect-garbage:*)"

    # JavaScript - cache corruption
    "Bash(npm cache clean --force:*)"

    # Cloudflare - resource deletion
    "Bash(wrangler delete:*)"
  ];

  # Claude's file permission rules use gitignore-style patterns. Absolute
  # filesystem paths must use the documented //path form; a single leading slash
  # is relative to the project root and does not protect home-directory secrets.
  readDeny = [
    # Environment files (relative and absolute)
    "Read(./.env)"
    "Read(./.env.*)"
    "Read(**/.env)"
    "Read(**/.env.*)"

    # Secrets directories (relative and absolute)
    "Read(./secrets/**)"
    "Read(**/secrets/**)"
    "Read(**/.secrets/**)"

    # SSH keys (fully qualified paths)
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.ssh/**"})"
    "Read(**/*_rsa)"
    "Read(**/*_rsa.*)"
    "Read(**/*_ed25519)"
    "Read(**/*_ed25519.*)"
    "Read(**/*_ecdsa)"
    "Read(**/*_ecdsa.*)"

    # Key files by extension
    "Read(*.pem)"
    "Read(*.key)"

    # GPG keys (fully qualified paths)
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.gnupg/**"})"

    # Cloud credentials (fully qualified paths)
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.aws/**"})"
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.azure/**"})"
    "Read(${claudeAbsolutePattern "${config.xdg.configHome}/gcloud/**"})"

    # VCS credentials (fully qualified paths)
    "Read(${claudeAbsolutePattern "${config.xdg.configHome}/gh/hosts.yml"})"
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.git-credentials"})"
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.netrc"})"

    # Container/Kubernetes secrets (fully qualified paths)
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.docker/config.json"})"
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.kube/**"})"

    # Shell history (fully qualified paths - may contain passwords)
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.bash_history"})"
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.zsh_history"})"
    "Read(${claudeAbsolutePattern "${config.home.homeDirectory}/.fish_history"})"
    "Read(${claudeAbsolutePattern "${config.xdg.dataHome}/fish/fish_history"})"
  ];

  inherit (config.claude-code) lspServers;

  # Wrap Claude Code with LSP plugin support when language modules contribute
  # LSP server configurations. Sets ENABLE_LSP_TOOL=1 and passes --plugin-dir
  # pointing to the generated .lsp.json location. When no LSP servers are
  # configured, the unwrapped package is used unchanged.
  claudePackageWithLsp =
    if lspServers != { } then
      pkgs.symlinkJoin {
        name = "claude-code-with-lsp";
        paths = [ claudePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude \
            --set ENABLE_LSP_TOOL 1 \
            --add-flags "--plugin-dir ${config.home.homeDirectory}/.claude/plugins/nix-lsp"
        '';
      }
    else
      claudePackage;
in
{
  options.claude-code.lspServers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
    default = { };
    description = "LSP server configurations contributed by language modules, merged into .lsp.json";
  };

  config = {
    home = {
      file = lib.mkIf (lspServers != { }) {
        ".claude/plugins/nix-lsp/.lsp.json".text = builtins.toJSON lspServers;
      };
      packages = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ccusage
        ccstatuslinePatched
      ];
      shellAliases = {
        cc-traya = "claude --agent traya --continue";
      };
    };

    # Declarative configuration for ccstatusline.
    # Settings are written to ~/.config/ccstatusline/settings.json, which is the
    # default path the tool reads on startup. The status line command is injected
    # into Claude Code's settings.json by the claude-code Home Manager module.
    xdg.configFile."ccstatusline/settings.json".text = builtins.toJSON {
      version = 3;
      # Plain values required: builtins.toJSON serialises lib.mkDefault wrappers
      # verbatim as attribute sets, which fails ccstatusline's Zod schema validation.
      flexMode = "full-minus-40";
      compactThreshold = 60;
      colorLevel = 2;
      defaultPadding = " ";
      defaultSeparator = "|";
      inheritSeparatorColors = false;
      globalBold = false;
      powerline = {
        enabled = false;
        separators = [ "\uE0B0" ];
        separatorInvertBackground = [ false ];
        startCaps = [ ];
        endCaps = [ ];
        autoAlign = false;
      };
      lines = [
        [
          # Line 1: model identity, session information, and block timing.
          # Explicit separator widgets are intentionally absent: defaultSeparator
          # already inserts a "|" between every adjacent widget pair automatically.
          # Adding both causes triple separators (defaultSep + widget + defaultSep).
          {
            id = "1";
            type = "model";
            color = "cyan";
          }
          {
            id = "3";
            type = "session-clock";
            color = "yellow";
          }
          {
            id = "5";
            type = "session-usage";
            color = "brightBlue";
          }
          {
            id = "7";
            type = "session-cost";
            color = "green";
          }
          # Block Reset Timer uses type "reset-timer" per the widget manifest
          # (BlockResetTimerWidget is registered under that key, not "block-reset-timer").
          {
            id = "10";
            type = "block-timer";
            color = "yellow";
          }
          {
            id = "12";
            type = "reset-timer";
            color = "brightYellow";
          }
          # Weekly widgets follow the block timers on the same line. When no
          # weekly usage data is available they return null and are skipped by the
          # renderer, so no blank line is ever reserved.
          {
            id = "14";
            type = "weekly-usage";
            color = "brightBlue";
          }
          {
            id = "16";
            type = "weekly-reset-timer";
            color = "brightCyan";
          }
          {
            id = "9";
            type = "session-name";
            color = "magenta";
          }
        ]
        [
          # Line 3: token counts and context bar.
          {
            id = "17";
            type = "tokens-input";
            color = "brightBlack";
          }
          {
            id = "19";
            type = "tokens-output";
            color = "brightBlack";
          }
          {
            id = "21";
            type = "tokens-cached";
            color = "brightBlack";
          }
          {
            id = "23";
            type = "tokens-total";
            color = "white";
          }
          {
            id = "25";
            type = "context-bar";
            color = "brightGreen";
          }
        ]
      ];
    };
    programs = {
      claude-code = {
        enable = true;
        package = claudePackageWithLsp;
        # Use Home Manager's native MCP support with shared server definitions
        inherit (mcpServerDefs) mcpServers;
        settings = {
          # MCP servers are selected declaratively through Home Manager. Their
          # tools are allowed below with mcp__*, while arbitrary project MCP
          # servers remain opt-in instead of being silently trusted.
          enableAllProjectMcpServers = false;

          # These roots are treated like the launch directory for file access.
          # With defaultMode = "acceptEdits", workspace edits in these roots do
          # not prompt, and the same policy applies to delegated subagents.
          additionalDirectories = claudeWorkspaceRoots;

          # Wire ccstatusline into Claude Code's status bar. The module writes
          # this value to ~/.claude/settings.json under the "statusLine" key,
          # which Claude Code reads on startup to invoke the formatter.
          statusLine = {
            type = "command";
            command = lib.getExe ccstatuslinePatched;
            padding = 0;
          };
          permissions = {
            allow =
              bashAllow
              ++ claudeWorkspaceEditRules
              ++ [
                # MCP tools - allow all unconditionally
                "mcp__*"

                # Web fetching - allow without prompting
                "WebFetch"
              ];
            ask = bashAsk ++ bashAskDestructive;
            deny = bashDeny ++ readDeny;
            defaultMode = "acceptEdits";
          };
        };
      };
    };
  };
}
