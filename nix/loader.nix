# Managed by Tailor: nix/loader.nix
{ pkgs, ... }:
builtins.seq pkgs (
  builtins.concatLists [
    (if builtins.pathExists ./ntrecord.nix then import ./ntrecord.nix { inherit pkgs; } else [ ])
    (if builtins.pathExists ./go.nix then import ./go.nix { inherit pkgs; } else [ ])
    (
      if builtins.pathExists ./go-ebitengine.nix then
        import ./go-ebitengine.nix { inherit pkgs; }
      else
        [ ]
    )
    (if builtins.pathExists ./python.nix then import ./python.nix { inherit pkgs; } else [ ])
    (if builtins.pathExists ./rust.nix then import ./rust.nix { inherit pkgs; } else [ ])
    (if builtins.pathExists ./javascript.nix then import ./javascript.nix { inherit pkgs; } else [ ])
    (if builtins.pathExists ./shell.nix then import ./shell.nix { inherit pkgs; } else [ ])
    (
      if builtins.pathExists ./go-ffmpeg-statigo.nix then
        import ./go-ffmpeg-statigo.nix { inherit pkgs; }
      else
        [ ]
    )
    (if builtins.pathExists ./pages.nix then import ./pages.nix { inherit pkgs; } else [ ])
    (if builtins.pathExists ./og.nix then import ./og.nix { inherit pkgs; } else [ ])
    (if builtins.pathExists ./playwright.nix then import ./playwright.nix { inherit pkgs; } else [ ])
    (if builtins.pathExists ./blender.nix then import ./blender.nix { inherit pkgs; } else [ ])
  ]
)
