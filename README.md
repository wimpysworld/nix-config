# Wimpy's [NixOS]  & [Home Manager] Configurations

[NixOS]: https://nixos.org/
[Home Manager]: https://github.com/nix-community/home-manager

This repository contains a [Nix Flake](https://nixos.wiki/wiki/Flakes) for configuring my computers and home environment. These are the computers this configuration currently manages:

|    Hostname    |       OEM      |        Model        |       OS      |     Role     |  Status  |
| :------------: | :------------: | :-----------------: | :-----------: | :----------: | :------- |
| `designare`    | DIY            | i9-9900K            | NixOS         | Desktop      | Done     |
| `noname`       | DIY            | AMD 5900X, 6900 XT  | NixOS         | Gamestation  | Done     |
| `node202`      | DIY            | AMD 5700G, 6700 XT  | ChimeraOS     | Gamestation  | Done     |
| `vm`           | VM             | -                   | NixOS         | Desktop      | Done     |
| `ripper`       | DIY            | AMD 3970X           | NixOS         | Desktop      | Done     |
| `nuc`          | Intel          | [NUC5i7RYH]         | NixOS         | Server       | WIP      |
| `skull`        | Intel          | [NUC6i7KYK]         | NixOS         | Server       | Done     |
| `brix`         | Gigabyte       | [GB-BXCEH-2955]     | NixOS         | Server       | WIP      |
| `trooper`      | DIY            | AMD 5950X, 3080Ti   | NixOS         | Desktop      | Done     |
| `zed`          | Lenovo         | ThinkPad Z13 Gen 1  | NixOS         | Laptop       | Done     |
| `p1`           | Lenovo         | ThinkPad P1 Gen 1   | NixOS         | Laptop       | Done     |
| `pi4`          | Raspberry Pi   | Raspberry Pi 4      | Ubuntu MATE   | Desktop      | tbn      |
| `pinebook`     | Pine64         | Pinebook            | -             | Laptop       | tbn      |
| `pinebook-pro` | Pine64         | Pinebook Pro        | -             | Laptop       | tbn      |
| `c630`         | Lenovo         | Yoga C630           | Windows 10S   | Laptop       | tbn      |
| `pocket`       | GPD            | Pocket              | Ubuntu MATE   | Laptop       | tbn      |
| `pocket2`      | GPD            | Pocket 2            | Ubuntu MATE   | Laptop       | tbn      |
| `pocket3`      | GPD            | Pocket 3            | Ubuntu MATE   | Laptop       | tbn      |
| `p2-max`       | GPD            | P2 Max              | NixOS         | Laptop       | Done     |
| `micropc`      | GPD            | Micro PC            | NixOS         | Laptop       | WIP      |
| `win2`         | GPD            | WIN 2               | NixOS         | Laptop       | WIP      |
| `win-max`      | GPD            | WIN Max             | NixOS         | Laptop       | WIP      |
| `falcon`       | TopJoy         | Falcon              | Ubuntu MATE   | Laptop       | tbn      |
| `macbookpro`   | Apple          | Macbook Pro 2015    | macOS         | Laptop       | tbn      |
| `xps-13`       | Dell           | XPS 13 9360         | Ubuntu MATE   | Laptop       | tbn      |
| `spectre`      | HP             | Spectre 13          | Ubuntu MATE   | Laptop       | tbn      |
| `apollo`       | Entroware      | Apollo 2000         | Ubuntu MATE   | Laptop       | tbn      |

[NUC5i7RYH]: https://www.intel.co.uk/content/www/uk/en/products/sku/87570/intel-nuc-kit-nuc5i7ryh/specifications.html
[NUC6i7KYK]: https://ark.intel.com/content/www/us/en/ark/products/89187/intel-nuc-kit-nuc6i7kyk.html
[GB-BXCEH-2955]: https://www.gigabyte.com/uk/Mini-PcBarebone/GB-BXCEH-2955-rev-10
[GB-BXCEH-2955 Review]: https://nucblog.net/2014/11/gigabyte-brix-2955u-review/

**As featured on [Linux Matters](https://linuxmatters.sh) podcast!** 🎙️ I am a presenter on Linux Matters and this configuration was featured in [Episode 7 - Immutable Desktop Linux for Anyone](https://linuxmatters.sh/7/).

<div align="center">
  <a href="https://linuxmatters.sh" target="_blank"><img src="./.github/screenshots/linuxmatters.png" alt="Linux Matters Podcast"/></a>
  <br />
  <em>Linux Matters Podcast</em>
</div>

## Structure

- [.github]: GitHub CI/CD workflows Nix ❄️ supercharged ⚡️ by [**Determinate Systems**](https://determinate.systems) 
  - [Nix Installer Action](https://github.com/marketplace/actions/the-determinate-nix-installer)
  - [Magic Nix Cache Action](https://github.com/marketplace/actions/magic-nix-cache)
  - [Flake Checker Action](https://github.com/marketplace/actions/nix-flake-checker)
  - [Update Flake Lock Action](https://github.com/marketplace/actions/update-flake-lock)
- [home-manager]: Home Manager configurations
  - Sane defaults for shell and desktop
- [nixos]: NixOS configurations
  - Includes discrete hardware configurations which leverage the [NixOS Hardware modules](https://github.com/NixOS/nixos-hardware) via [flake.nix].
- [scripts]: Helper scripts
- [shells]: [Nix shell environments using direnv](https://determinate.systems/posts/nix-direnv) for infrequently used tools

The [nixos/_mixins] and [home-manager/_mixins] are a collection of composited configurations based on the arguments defined in [flake.nix].

[.github]: ./github/workflows
[home-manager]: ./home-manager
[nixos]: ./nixos
[nixos/_mixins]: ./nixos/_mixins
[home-manager/_mixins]: ./home-manager/_mixins
[flake.nix]: ./flake.nix
[scripts]: ./scripts
[shells]: ./shells

## Installing 💾

- Boot off a .iso image created by this flake using `rebuild-iso-desktop` or `rebuild-iso-console` (*see below*)
- Put the .iso image on a USB drive
- Boot the target computer from the USB drive
- Two installation options are available:
  1 Use the graphical Calamares installer to install an adhoc system
  2 Run `install-system <hostname> <username>` from a terminal
   - The install script uses [Disko] to automatically partition and format the disks, then uses my flake via `nixos-install` to complete a full-system installation
   - This flake is copied to the target user's home directory as `~/Zero/nix-config`
- Make a cuppa 🫖
- Reboot
- Login and run `rebuild-home` (*see below*) from a terminal to complete the Home Manager configuration.

If the target system is booted from something other than the .iso image created by this flake, you can still install the system using the following:

```bash
curl -sL https://raw.githubusercontent.com/wimpysworld/nix-config/main/scripts/install.sh | bash -s <hostname> <username>
```

## Applying Changes ✨

I clone this repo to `~/Zero/nix-config`. NixOS and Home Manager changes are applied separately because I have some non-NixOS hosts.

```bash
gh repo clone wimpysworld/nix-config ~/Zero/nix-config
```

### NixOS ❄️

A `rebuild-host` alias is provided that does the following:

```bash
sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
```

### Home Manager 🏠️

A `rebuild-home` alias is provided that does the following:

```bash
home-manager switch -b backup --flake $HOME/Zero/nix-config
```

### ISO 📀

Aliases for `rebuild-iso-desktop` (*desktop*) and `rebuild-iso-console` (*console only*) are provided that create .iso images from this flake. They do the following:

```bash
pushd $HOME/Zero/nix-config
nix build .#nixosConfigurations.iso.config.system.build.isoImage
popd
```

A live image will be left in `~/$HOME/Zero/nix-config/result/iso/`. These .iso images are also periodically built and published via [GitHub Actions](./.github/workflows) and available in [this project's Releases](https://github.com/wimpysworld/nix-config/releases).

## What's in the box? 🎁

Nix is configured with [flake support](https://zero-to-nix.com/concepts/flakes) and the [unified CLI](https://zero-to-nix.com/concepts/nix#unified-cli) enabled.

### Structure

Here is the directory structure I'm using.

```
.
├── home-manager
│   ├── _mixins
│   │   ├── console
│   │   ├── desktop
│   │   ├── services
│   │   └── users
│   └── default.nix
├── nixos
│   ├── _mixins
│   │   ├── desktop
│   │   ├── hardware
│   │   ├── services
│   │   ├── users
│   │   └── virt
│   ├── designare
│   ├── iso
│   ├── skull
│   ├── vm
│   ├── z13
│   └── default.nix
├── overlays
├── pkgs
├── scripts
└── flake.nix
```

### The Shell 🐚

[Fish shell] with [powerline-go](https://github.com/justjanne/powerline-go) and a collection of tools that deliver a somewhat *"[Modern Unix]"* experience. The base system has a firewall enabled and also includes [OpenSSH], [ZeroTier], [Podman & Distrobox] and, of course, a delightfully configured [micro]. (*Fight me!* 🥊)

[Fish shell]: ./nixos/default.nix
[Modern Unix]: ./home-manager/_mixins/console/default.nix
[OpenSSH]: ./nixos/_mixins/services/openssh.nix
[ZeroTier]: ./nixos/_mixins/services/zerotier.nix
[Podman & Distrobox]: ./nixos/_mixins/virt/podman.nix
[micro]: [https://micro-editor.github.io/]

![neofetch on Designare](.github/screenshots/neofetch.png)

### The Desktop 🖥️

MATE Desktop 🧉 and Pantheon 🏛️ are the two desktop options available. The [font configuration] is common with both desktops using [Work Sans](https://fonts.google.com/specimen/Work+Sans) and [Fira Code](https://fonts.google.com/specimen/Fira+Code). The usual creature comforts you'd expect to find in a Linux Desktop are integrated such as [Pipewire], Bluetooth, [Avahi], [CUPS], [SANE] and [NetworkManager].

[font configuration]: ./nixos/_mixins/desktop/default.nix
[Pipewire]: ./nixos/_mixins/services/pipewire.nix
[Avahi]: ./nixos/_mixins/services/avahi.nix
[CUPS]: ./nixos/_mixins/services/cups.nix
[SANE]: ./nixos/_mixins/services/sane.nix
[NetworkManager]: ./nixos/_mixins/services/networkmanager.nix

|  Desktop  |       System       |       Configuration       |             Theme            |
| :-------: | :----------------: | :-----------------------: | :--------------------------: |
| MATE      | [MATE Install]     | [MATE Configuration]      | Yaru Magenta (Dark)          |
| Pantheon  | [Pantheon Install] | [Pantheon Configuration]  | elementary Bubble Gum (Dark) |

[MATE Install]: ./nixos/_mixins/desktop/mate.nix
[Pantheon Install]: ./nixos/_mixins/desktop/pantheon.nix
[MATE Configuration]: ./home-manager/_mixins/desktop/mate.nix
[Pantheon Configuration]: ./home-manager/_mixins/desktop/pantheon.nix

## Eye Candy 👀🍬

![Pantheon on Designare](.github/screenshots/pantheon.png)

## TODO 🗒️

### Hardware

- [x] Add all computers to the table
- [x] Implement [Disko](https://github.com/nix-community/disko) partitioning
- [x] Integrate [.iso building](https://www.reddit.com/r/NixOS/comments/y1xo2u/comment/irzwe95/)
- [x] Integrate OpenRGB
- [x] Integrate OpenRazer
- [x] Integrate StreamDeck
- [x] Integrate Xone
- [ ] ~~Migrate (*maybe*) to ZFS, with backups via [`zrepl`](https://zrepl.github.io/)~~
- [x] Fix Magewell mwprocapture driver: [nixpkgs#221209](https://github.com/NixOS/nixpkgs/pull/221209)
  - [ ] [And again](https://github.com/NixOS/nixpkgs/pull/247897)

### Applications

- [x] Integrate an Emoji picker
- [x] Integrate AppCenter and Flathub
- [x] Integrate Steam
- [ ] Add Ferdium, Rambox or Wavebox
- [ ] Add Password Managers

### Services

- [ ] Integrate Borg Backups
  - [x] [Vorta](https://vorta.borgbase.com/) for workstations
  - [ ] [borgmatic](https://torsion.org/borgmatic/) for servers
- [ ] ~~Integrate cockpit (*server*)~~
- [ ] Integrate [notify](https://github.com/projectdiscovery/notify)
- [ ] Integrate Plex (*skull*)
- [ ] Integrate homepage
- [x] Integrate fwupd
- [x] Integrate Keybase
- [x] Integrate Syncthing
- [x] Integrate sshguard

### Configuration

- [x] Embed [install script in the ISO](./nixos/_mixins/users/nixos/console.nix)
- [ ] Integrate [agenix](https://github.com/ryantm/agenix) ~~or [sops-nix](https://github.com/Mic92/sops-nix)~~
- [x] Integrate capabilities from [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)
- [x] Integrate wallpapers
- [x] Integrate faces
- [x] Include Serif fonts
- [x] Include fallback fonts for Work Sans, Fira Code and Joypixels
- [x] Create common user settings and discrete user settings
- [x] Move application defaults out of the desktop defaults
- [x] Create standard directories in `/home/martin` using `systemd.user.tmpfiles.rules`.
- [x] Create `.envrc` files in `/home/martin`.
- [ ] Bind Syncthing GUI to ZeroTier.
- [ ] Configure Plank.
- [x] Fix [Unfree in Home Manager](https://github.com/Misterio77/nix-starter-configs/blob/main/minimal/home-manager/home.nix#L31))

### Game Development

- [ ] Defold
- [ ] Godot
- [ ] PICO-8

### Shell

- [ ] fzf
- [ ] tmate or tmux
- [x] micro
- [ ] nnn or broot or felix or ranger

## Inspirations 🧑‍🏫

Before preparing my NixOS and Home Manager configurations I took a look at what other Nix users are doing. My colleagues shared their configs and tips which included [nome from Luc Perkins], [nixos-config from Cole Helbling], [flake from Ana Hoverbear] and her [Declarative GNOME configuration with NixOS] blog post. A couple of friends also shared their configurations and here's [Jon Seager's nixos-config] and [Aaron Honeycutt's nix-configs].

While learning Nix I watched some talks/interviews with [Matthew Croughan](https://github.com/MatthewCroughan) and [Will Taylor's Nix tutorials on Youtube](https://www.youtube.com/playlist?list=PL-saUBvIJzOkjAw_vOac75v-x6EzNzZq-). [Will Taylor's dotfiles] are worth a look, as are his videos, and [Matthew Croughan's nixcfg] is also a useful reference. **After I created my initial flake I found [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) by [Gabriel Fontes](https://m7.rs) which is an excellent starting point**. I'll be incorporating many of the techniques it demonstrates in my nix-config.

I like the directory hierarchy in [Jon Seager's nixos-config] and the mixin pattern used in [Matthew Croughan's nixcfg], so my initial Nix configuration is heavily influenced by both of those. Ana's excellent [Declarative GNOME configuration with NixOS] blog post was essential to get a personalised desktop. That said, there's plenty to learn from browsing other people's Nix configurations, not least for discovering cool software. I recommend a search of [GitHub nixos configuration] from time to time to see what interesting techniques you pick up and new tools you might discover.

The [Disko] implementation and automated installation is chasing the ideas outlined in these blog posts:
  - [Setting up my new laptop: nix style](https://bmcgee.ie/posts/2022/12/setting-up-my-new-laptop-nix-style/)
  - [Setting up my machines: nix style](https://aldoborrero.com/posts/2023/01/15/setting-up-my-machines-nix-style/)

[nome from Luc Perkins]: https://github.com/the-nix-way/nome
[nixos-config from Cole Helbling]: https://github.com/cole-h/nixos-config
[flake from Ana Hoverbear]: https://github.com/Hoverbear-Consulting/flake
[Declarative GNOME configuration with NixOS]: https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/
[Jon Seager's nixos-config]: https://github.com/jnsgruk/nixos-config
[Aaron Honeycutt's nix-configs]: https://gitlab.com/ahoneybun/nix-configs
[Matthew Croughan's nixcfg]: https://github.com/MatthewCroughan/nixcfg
[Will Taylor's dotfiles]: https://github.com/wiltaylor/dotfiles
[GitHub nixos configuration]: https://github.com/search?q=nixos+configuration
[Disko]: https://github.com/nix-community/disko
