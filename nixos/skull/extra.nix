{ ... }: {
  imports = [
    ../_mixins/services/tailscale.nix
    ../_mixins/services/zerotier.nix
  ];
}
