{ ... }: {
  imports = [
    ../_mixins/services/syncthing
    ../_mixins/services/tailscale.nix
    ../_mixins/services/zerotier.nix
    ../_mixins/virt
  ];
}
