# Wimpy's [NixOS]  & [Home Manager] Configurations

[NixOS]: https://nixos.org/
[Home Manager]: https://github.com/nix-community/home-manager

This repository contains a [Nix Flake](https://nixos.wiki/wiki/Flakes) for configuring my computers and home environment. These are the computers this configuration currently manages:

|  Hostname   |        Model        |  Role   |  Status  |
| :---------: | :-----------------: | :-----: | :------- |
| `designare` | DIY i9-9900K        | Desktop | Done     |
| `z13`       | Lenono ThinkPad Z13 | Laptop  | WIP      |
| `skull`     | Intel NUC6i7KYK     | Server  | WIP      |

## Structure

- [home]: Home Manager configurations
  - Sane defaults for shell and desktop
- [host]: NixOS configurations
  - Includes discrete hardware configurations which leverage the [NixOS Hardware modules](https://github.com/NixOS/nixos-hardware) via [flake.nix].
- [scripts]: Helper scripts

The [host/_mixins] and [home/_mixins] are a collection of generic configurations that are composited based on the arguments defined in [flake.nix].

[home]: ./home
[host]: ./host
[host/_mixins]: ./host/_mixins
[home/_mixins]: ./home/_mixins
[flake.nix]: ./flake.nix
[scripts]: ./scripts

## Applying Changes

I clone this repo to `~/Zero/nix-config`. Home Manager and NixOS changes can be applied separately because I am planning to add support for some non-NixOS hosts.

```bash
gh repo clone wimpysworld/nix-config ~/Zero/nix-config
```

### NixOS ❄️

A `rebuild-host` alias is provided, that does the following:

```bash
sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
```

### Home Manager 🏠️

A `rebuild-home` alias is provided, that does the following:

```bash
home-manager switch -b backup --flake $HOME/Zero/nix-config
```

## What's in the box? 🎁

Nix is configured with [flake support](https://zero-to-nix.com/concepts/flakes) and the [unified CLI](https://zero-to-nix.com/concepts/nix#unified-cli) enabled.

### The Shell 🐚

[Fish shell] with powerline-go and a collection of tools that deliver a somewhat *"[Modern Unix]"* experience. The base system has a firewall enabled and also includes [OpenSSH], [Tailscale], [Docker] and, of course, a delightfully configured [nano]. (*Fight me!* 🥊)

[Fish shell]: ./home/_mixins/console/fish.nix
[Modern Unix]: ./home/_mixins/console/default.nix
[OpenSSH]: ./host/_mixins/services/openssh.nix
[Tailscale]: ./host/_mixins/services/tailscale.nix
[Docker]: ./host/_mixins/boxes/docker.nix
[nano]: ./host/_mixins/console/nano.nix

![neofetch on Designare](.github/screenshots/neofetch.png)

### The Desktop 🖥️

MATE Desktop 🧉 and Pantheon 🏛️ are the two desktop options available. The [font configuration] is common with both desktops using [Work Sans](https://fonts.google.com/specimen/Work+Sans) and [Fira Code](https://fonts.google.com/specimen/Fira+Code). The usual creature comforts you'd expect to have in a Linux Desktop are integrated such as [Pipewire], Bluetooth, [Avahi], [CUPS], [SANE] and [NetworkManager].

[font configuration]: ./host/_mixins/desktop/default.nix
[Pipewire]: ./host/_mixins/services/pipewire.nix
[Avahi]: ./host/_mixins/services/avahi.nix
[CUPS]: ./host/_mixins/services/cups.nix
[SANE]: ./host/_mixins/services/sane.nix
[NetworkManager]: ./host/_mixins/services/networkmanager.nix

|  Desktop  |       System       |       Configuration       |             Theme            |
| :-------: | :----------------: | :-----------------------: | :--------------------------: |
| MATE      | [MATE Install]     | [MATE Configuration]      | Yaru Magenta (Dark)          |
| Pantheon  | [Pantheon Install] | [Pantheon Configuration]  | elementary Bubble Gum (Dark) |

[MATE Install]: ./host/_mixins/desktop/mate.nix
[Pantheon Install]: ./host/_mixins/desktop/pantheon.nix
[MATE Configuration]: ./home/_mixins/desktop/mate.nix
[Pantheon Configuration]: ./home/_mixins/desktop/pantheon.nix

## Eye Candy 👀🍬

![Pantheon on Designare](.github/screenshots/pantheon.png)

## TODO 🗒️

- [ ] Implement [Disko](https://github.com/nix-community/disko) partitioning
- [ ] Integrate Keybase
- [ ] Integrate an emoji Picker
- [ ] Integrate AppCenter and Flathub
- [ ] Integrate Steam
- [ ] Include image assets such as wallpapers and faces
- [ ] Include Serif fonts and fallbacks for Work Sans and Fira Code.
- [ ] Move user-specific settings to Home Manager
- [ ] Move application defaults out of the desktop defaults
- [ ] Add all computers to the table
- [ ] Fix [Unfree in Home Manager](https://nixos.wiki/wiki/Flakes#Enable_unfree_software)
- [ ] Fix Magewell driver
  - `linuxKernel.packages.linux_6_2.mwprocapture`
    - `hardware.mwProCapture.enable = true;`
