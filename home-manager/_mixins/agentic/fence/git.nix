{ config, pkgs }:

let
  # Work clones under ~/Chainguard sign with gitsign, which needs no key inside
  # the sandbox. Everywhere else the base configuration signs with an SSH key
  # that Fence read-denies, so signing must be off or the commit fails.
  #
  # Git evaluates the `includeIf` condition per repository, every time it runs.
  # So the launch directory stops mattering, and so do a later `cd`, `git -C`,
  # and `GIT_DIR`. An agent launched from ~/.herdr, which belongs to no
  # repository, still signs correctly once it reaches a work clone.
  #
  # `GIT_CONFIG_*` cannot express this. Those variables carry `command line:`
  # origin, which outranks every configuration file including a conditional
  # include, so an injected `commit.gpgSign=false` would win inside work clones
  # too. The two mechanisms cannot coexist, hence a Fence-owned global file.
  #
  # The condition matches `home-manager/_mixins/users/martin/git.nix`, so the
  # two stay consistent. It requires a path component between Chainguard and
  # the Git directory, so ~/Chainguard/<repo>/.git matches while the
  # ~/Chainguard/.git of the cg-env repository does not. cg-env therefore keeps
  # the unsigned path.
  workOverrideConfig = pkgs.writeText "fence-git-work.conf" ''
    [commit]
    	gpgSign = true
    [tag]
    	gpgSign = true
  '';

  # Fence bind-mounts `<repo>/.git/config` and `<repo>/.git/hooks` read-only
  # inside the sandbox. That is Fence's own protection, not this policy, and it
  # has no configuration switch. Git writes `config.lock` and then renames it
  # over `config`, and the kernel refuses a rename onto a mount point, so every
  # local write fails with `Device or resource busy`. Exposing the file
  # read-write would not help, because a read-write bind is still a mount point.
  #
  # The one thing a fenced agent loses is branch tracking: `git push -u` pushes
  # the branch and then fails to record the upstream. The base configuration
  # sets `push.default = matching`, under which a bare `git push` on a branch
  # the remote does not have yet pushes nothing and still exits zero. Pair those
  # two and an agent can believe it pushed when it did not.
  #
  # `push.default = current` removes the dependency. A bare `git push` sends the
  # current branch to the branch of the same name on the remote and creates it
  # when it is missing, with no upstream and no local configuration write. Only
  # fenced agents get this; the interactive configuration keeps `matching`.
  #
  # Order matters: later settings win. Pull in the real global configuration
  # first, turn signing off, then turn it back on for work clones only.
  fenceGitConfig = pkgs.writeText "fence-git.conf" ''
    [include]
    	path = ${config.xdg.configHome}/git/config
    [commit]
    	gpgSign = false
    [tag]
    	gpgSign = false
    [push]
    	default = current
    [includeIf "gitdir:~/Chainguard/*/"]
    	path = ${workOverrideConfig}
  '';
in
{
  setupShell = ''
    fence_env+=(
      "GIT_CONFIG_GLOBAL=${fenceGitConfig}"
    )
  '';
}
