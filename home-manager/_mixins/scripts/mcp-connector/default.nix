{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      curl
      fd
      gh
      git
      unstable.github-mcp-server
      gnused
      gnugrep
      jq
      unstable.mcp-nixos
      nodejs_24
      pm2
      pnpm
      python3
      tailscale
      unstable.terraform-mcp-server
      coreutils
      uv
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home.packages = with pkgs; [ shellApplication ];
}
