# Wimpy's [NixOS]  & [Home Manager] Configurations

This repository contains a [Nix Flake](https://zero-to-nix.com/concepts/flakes) for configuring my computers and/or home environment.
It is not intended to be a drop in configuration for your computer, but you are welcome to use it as a reference or starting point for your own configuration.
**If you are looking for a more generic NixOS configuration, I recommend [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs).** 👍️
These computers are managed by this Nix flake ❄️

|   Hostname  |            Board            |               CPU              |  RAM  |         Primary GPU         |      Secondary GPU      | Role | OS  | State |
| :---------: | :-------------------------: | :----------------------------: | :---: | :-------------------------: | :---------------------: | :--: | :-: | :---: |
| `vader`     | [MEG-X570-UNIFY]            | [AMD Ryzen 9 5950X]            | 128GB | [Fighter RX 6700 XT]        | [NVIDIA T1000]          | 🖥️   | ❄️  | ✅    |
| `phasma`    | [MEG-X570-ACE]              | [AMD Ryzen 9 5900X]            | 128GB | [Fighter RX 6700 XT]        | [NVIDIA T600]           | 🖥️   | ❄️  | ✅    |
| `palpatine` | [ThinkPad P1 Gen 1]         | [Intel Xeon E-2176M]           | 64GB  | [NVIDIA Quadro P2000 Max-Q] | Intel UHD Graphics P630 | 💻️🎭️ | 🪟  | ✅    |
| `sidious`   | [ThinkPad P1 Gen 1]         | [Intel Xeon E-2176M]           | 64GB  | [NVIDIA Quadro P2000 Max-Q] | Intel UHD Graphics P630 | 💻️🎭️ | ❄️  | 🚧    |
| `tanis`     | [ThinkPad Z13 Gen 1]        | [AMD Ryzen 5 PRO 6650U]        | 32GB  | AMD Radeon 660M             |                         | 💻️   | ❄️  | 🚧    |
| `dooku`     | [Macbook Air M2 15"]        | Apple M2 8-core CPU            | 24GB  | Apple M2 10-core GPU        |                         | 💻️🎭️ | 🍏  | 🚧    |
| `tyranus`   | [Macbook Air M2 15"]        | Apple M2 8-core CPU            | 24GB  | Apple M2 10-core GPU        |                         | 💻️🎭️ | ❄️  | 🚧    |
| `steamdeck` | [Steam Deck 64GB LCD]       | Zen 2 4c/8t                    | 16GB  | 8 RDNA 2 CUs                |                         | 🎮️   | 🐧  | ✅    |
| `minimech`  | [QEMU]                      | -                              | -     | [VirGL]                     |                         | 🐄   | ❄️  | ✅    |
| `scrubber`  | [QEMU]                      | -                              | -     | [VirGL]                     |                         | 🐄   | ❄️  | ✅    |
| `skull`     | [NUC6i7KYK]                 | [Intel Core i7-6770HQ]         | 64GB  | Intel Iris Pro Graphics 580 |                         | ☁️   | ❄️  | 🚧    |
| `designare` | [Z390-DESIGNARE]            | [Intel Core i9-9900K]          | 64GB  | [Intel Arc A770 16GB]       | Intel UHD Graphics 630  | ☁️   | ❄️  | 🚧    |
| `brix`      | [GB-BXCEH-2955]             | [Intel Celeron 2955U]          | 16GB  | Intel HD Graphics           |                         | ☁️   | ❄️  | 🧟    |
| `nuc`       | [NUC5i7RYH]                 | [Intel Core i7-5557U]          | 32GB  | Intel Iris Graphics 6100    |                         | ☁️   | ❄️  | 🧟    |
| ~~ripper~~  | [TRX40-DESIGNARE]           | [AMD Ryzen Threadripper 3970X] | 256GB | [GeForce RTX 3090 GAMING OC]|                         | 🖥️   | ❄️  | ⚰️    |
| ~~trooper~~ | [ROG Crosshair VIII Impact] | [AMD Ryzen 9 5950X]            | 64GB  | [Fighter RX 6800]           |                         | 🖥️   | ❄️  | ⚰️    |

**Key**

- 🎭️ : Dual boot
- 🖥️ : Desktop
- 💻️ : Laptop
- 🎮️ : Games Machine
- 🐄 : Virtual Machine
- ☁️ : Server

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
  - Includes discrete hardware configurations that leverage the [NixOS Hardware modules](https://github.com/NixOS/nixos-hardware).

The [nixos/_mixins] and [home-manager/_mixins] are a collection of composited configurations based on the arguments defined in [flake.nix].

## Installing 💾

- Boot off a .iso image created by this flake using `build-iso console` or `build-iso <desktop>` (*see below*)
- Put the .iso image on a USB drive
- Boot the target computer from the USB drive
- Two installation options are available:
  1 Use the graphical Calamares installer to install an ad-hoc system
  2 Run `install-system <hostname> <username>` from a terminal
   - The install script uses [Disko] or `disks.sh` to automatically partition and format the disks, then uses my flake via `nixos-install` to complete a full-system installation
   - This flake is copied to the target user's home directory as `~/Zero/nix-config`
   - The `nixos-enter` command is used to automatically chroot into the new system and apply the Home Manager configuration.
- Make a cuppa 🫖
- Reboot 🥾

## Applying Changes ✨

I clone this repo to `~/Zero/nix-config`. NixOS and Home Manager changes are applied separately because I have some non-NixOS hosts.

```bash
gh repo clone wimpysworld/nix-config ~/Zero/nix-config
```

- ❄️ **NixOS:**  A `build-host` and `switch-host` aliases are provided that build the NixOS configuration and switch to it respectively.
- 🏠️ **Home Manager:**  A `build-home` and `switch-home` aliases are provided that build the Home Manager configuration and switch to it respectively.
- 🌍️ **All:** There are also `build-all` and `switch-all` aliases that build and switch to both the NixOS and Home Manager configurations.

### ISO 📀

The `build-iso` script is included that creates .iso images from this flake. The following modes are available:

- `build-iso console` (*terminal environment*): Includes `install-system` for automated installation.
- `build-iso gnome` (*GNOME Desktop environment*): Includes `install-system` and [Calamares](https://calamares.io/) installation.
- `build-iso mate` (*MATE Desktop environment*): Includes `install-system` and [Calamares](https://calamares.io/) installation.
- `build-iso pantheon` (*Pantheon Desktop environment*): Includes `install-system` and [Calamares](https://calamares.io/) installation.

Live images will be left in `~/$HOME/Zero/nix-config/result/iso/` and are also injected into `~/Quickemu/nixos-console` and `~/Quickemu/nixos-<desktop>` respectively.
The console .iso image is also periodically built and published via [GitHub [Actions](./.github/workflows) and is available in [this](https://github.com/wimpysworld/nix-config/releases) project's Releases](https://github.com/wimpysworld/nix-config/releases).

## What's in the box? 🎁

Nix is configured with [flake support](https://zero-to-nix.com/concepts/flakes) and the [unified CLI](https://zero-to-nix.com/concepts/nix#unified-cli) enabled.

### Structure

Here's the directory structure I'm using:

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
│   │   │   ├── gnome
│   │   │   ├── mate
│   │   │   └── pantheon
│   │   ├── scripts
│   │   ├── services
│   │   └── users
│   ├── phasma
│   ├── vader
│   ├── minimech
│   ├── scrubber
│   └── default.nix
├── overlays
├── pkgs
├── secrets
└── flake.nix
```

The NixOS and Home Manager configurations are in the `nixos` and `home-manager` directories respectively, they are structured in the same way with `_mixins` directories that contain the mixin configurations that are used to compose the final configuration.
The `pkgs` directory contains my custom packages with package overlays in the `overlays` directory.
The `secrets` directory contains secrets managed by [sops-nix].
The `default.nix` files in the root of each directory are the entry points.

### The Shell 🐚

[Fish shell] with [powerline-go](https://github.com/justjanne/powerline-go) and a collection of tools that deliver a *"[Modern Unix]"* experience. The base system has a firewall enabled and also includes [OpenSSH], [sops-nix] for secret management, [ZeroTier], [Podman & Distrobox] and, of course, a delightfully configured [micro]. (*Fight me!* 🥊) My [common scripts](nixos/_mixins/scripts) are (slowly) being migrated to declarative Nix-managed scripts.

![fastfetch on Ripper](.github/screenshots/fastfetch.png)

### The Desktop 🖥️

GNOME 👣 MATE 🧉 and Pantheon 🏛️ desktop options are available. The font configuration is common for all desktops using [Work Sans](https://fonts.google.com/specimen/Work+Sans) and [Fira Code](https://fonts.google.com/specimen/Fira+Code). The usual creature comforts you'd expect to find in a Linux Desktop are integrated such as Pipewire, Bluetooth, Avahi, CUPS, SANE and NetworkManager.

|  Desktop  |       System       |       Configuration       |             Theme            |
| :-------: | :----------------: | :-----------------------: | :--------------------------: |
| GNOME     | [GNOME Install]    | [GNOME Configuration]     | Adwaita (Dark)               |
| MATE      | [MATE Install]     | [MATE Configuration]      | Yaru Magenta (Dark)          |
| Pantheon  | [Pantheon Install] | [Pantheon Configuration]  | elementary Bubble Gum (Dark) |

## Eye Candy 👀🍬

![Pantheon on Designare](.github/screenshots/pantheon.png)

![Alt](https://repobeats.axiom.co/api/embed/a82d5acf21276546e716d36dca41be774e6a5b74.svg "Repobeats analytics image")

## Post-install Checklist

Things I currently need to do manually after installation.

### Secrets

- [ ] Provision `~/.config/sops/age/keys.txt`. Optionally handled by `install-system`.
- [ ] Add `ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub` to `.sops.yaml`.
- [ ] Run `sops updatekeys secrets/secrets.yaml`
- [ ] Run `gpg-restore`
- [ ] LastPass - authenticate
- [ ] Authy - activate
- [ ] 1Password - authenticate

### Services

- [ ] Atuin - `atuin login -u <user>`
- [ ] Brave - enroll sync
- [ ] Chatterino - authenticate
- [ ] Discord - authenticate
- [ ] GitKraken - authenticate with GitHub
- [ ] Grammarly - authenticate
- [ ] IRCCloud - authenticate
- [ ] Maelstral - `maestral_qt`
- [ ] Matrix - authenticate
- [ ] Syncthing - Connect API and introduce host
- [ ] Tailscale - `sudo tailscale up`
- [ ] Telegram - authenticate
- [ ] Keybase - `keybase login`
- [ ] VSCode - authenticate with GitHub enable sync
- [ ] Wavebox - authenticate Google and restore profile
- [ ] ZeroTier - enable host `sudo zerotier-cli info`
- [ ] Run `fonts.sh` to install commercial fonts

### Windows Boot Manager on multi-disk systems

One of my laptops (`sidious`) is a multi-disk system with Windows 11 Pro 🪟 installed on a separate disk from NixOS.
The Windows EFI partition is not automatically detected by systemd-boot, because it is on a different disk.
The following steps are required to copy the Windows Boot Manager to the NixOS EFI partition so dual-booting is possible.

Find Windows EFI Partition

```shell
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
```

Mount Windows EFI Partition

```shell
sudo mkdir /mnt/win-efi
sudo mount /dev/nvme1n1p1 /mnt/win-efi
```

Copy Contents of Windows EFI to NixOS EFI

```shell
sudo rsync -av /mnt/win-efi/EFI/Microsoft/ /boot/EFI/Microsoft/
```

Clean up

```shell
sudo umount /mnt/win-efi
sudo rm -rf /mnt/win-efi
```

Reboot and systemd-boot should now offer the option to boot NixOS and Windows.

## TODO 🗒️

Things I should do or improve:

- [ ] Install Rosetta and disable Xcode Command Line tools on macOS
  - `softwareupdate --install-rosetta --agree-to-license`
- [ ] Migrate Borg Backups to [borgmatic](https://torsion.org/borgmatic/) via NixOS modules and Home Manager
- [ ] Integrate [notify](https://github.com/projectdiscovery/notify)
- [ ] Integrate [homepage](https://github.com/benphelps/homepage)
- [ ] Create gschema overrides for Pantheon & Plank

### Game Development

- [ ] Defold
- [ ] Godot
- [ ] PICO-8

### Shell

- [ ] `fzf`
- [ ] `tmate` or `tmux`
- [ ] `git-graph` and/or `git-igitt` integration

### Servers

- [ ] Forgejo or Gitea
- [ ] [microbin](https://github.com/szabodanika/microbin)

## Inspirations 🧑‍🏫

Before preparing my NixOS and Home Manager configurations I took a look at what other Nix users are doing. My colleagues shared their configs and tips which included [nome from Luc Perkins], [nixos-config from Cole Helbling], [flake from Ana Hoverbear] and her [Declarative GNOME configuration with NixOS] blog post. A couple of friends also shared their configurations and here's [Jon Seager's nixos-config] and [Aaron Honeycutt's nix-configs].

While learning Nix I watched some talks/interviews with [Matthew Croughan](https://github.com/MatthewCroughan) and [Will Taylor's Nix tutorials on Youtube](https://www.youtube.com/playlist?list=PL-saUBvIJzOkjAw_vOac75v-x6EzNzZq-). [Will Taylor's dotfiles] are worth a look, as are his videos, and [Matthew Croughan's nixcfg] is also a useful reference. **After I created my initial flake I found [nix-starter-configs] by [Gabriel Fontes](https://m7.rs) which is an excellent starting point**. I'll be incorporating many of the techniques it demonstrates in my nix-config.

I like the directory hierarchy in [Jon Seager's nixos-config] and the mixin pattern used in [Matthew Croughan's nixcfg], so my initial Nix configuration is heavily influenced by both of those. Ana's excellent [Declarative GNOME configuration with NixOS] blog post was essential to get a personalised desktop. That said, there's plenty to learn from browsing other people's Nix configurations, not least for discovering cool software. I recommend a search of [GitHub nixos configuration] from time to time to see what interesting techniques you pick up and new tools you might discover.

The [Disko] implementation and automated installation are chasing the ideas outlined in these blog posts:
- [Setting up my new laptop: nix style](https://bmcgee.ie/posts/2022/12/setting-up-my-new-laptop-nix-style/)
- [Setting up my machines: nix style](https://aldoborrero.com/posts/2023/01/15/setting-up-my-machines-nix-style/)

[nome from Luc Perkins]: https://github.com/the-nix-way/nome
[nixos-config from Cole Helbling]: https://github.com/cole-h/nixos-config
[flake from Ana Hoverbear]: https://github.com/Hoverbear-Consulting/flake
[Declarative GNOME configuration with NixOS]: https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/
[nix-starter-configs]: (https://github.com/Misterio77/nix-starter-configs)
[Jon Seager's nixos-config]: https://github.com/jnsgruk/nixos-config
[Aaron Honeycutt's nix-configs]: https://gitlab.com/ahoneybun/nix-configs
[Matthew Croughan's nixcfg]: https://github.com/MatthewCroughan/nixcfg
[Will Taylor's dotfiles]: https://github.com/wiltaylor/dotfiles
[GitHub nixos configuration]: https://github.com/search?q=nixos+configuration
[Disko]: https://github.com/nix-community/disko

[NixOS]: https://nixos.org/
[Home Manager]: https://github.com/nix-community/home-manager

[Z390-DESIGNARE]: https://www.gigabyte.com/Motherboard/Z390-DESIGNARE-rev-10#kf
[MEG-X570-UNIFY]: https://www.msi.com/Motherboard/MEG-X570-UNIFY
[MEG-X570-ACE]: https://www.msi.com/Motherboard/MEG-X570-ACE
[NUC5i7RYH]: https://www.intel.co.uk/content/www/uk/en/products/sku/87570/intel-nuc-kit-nuc5i7ryh/specifications.html
[NUC6i7KYK]: https://ark.intel.com/content/www/us/en/ark/products/89187/intel-nuc-kit-nuc6i7kyk.html
[TRX40-DESIGNARE]: https://www.gigabyte.com/Motherboard/TRX40-DESIGNARE-rev-10#kf
[ROG Crosshair VIII Impact]: https://rog.asus.com/uk/motherboards/rog-crosshair/rog-crosshair-viii-impact-model/
[ThinkPad P1 Gen 1]: https://www.lenovo.com/gb/en/p/laptops/thinkpad/thinkpadp/thinkpad-p1/22ws2wpp101
[ThinkPad Z13 Gen 1]: https://www.lenovo.com/gb/en/p/laptops/thinkpad/thinkpadz/thinkpad-z13-(13-inch-amd)/21d20012uk
[Macbook Air M2 15"]: https://www.apple.com/uk/macbook-air-13-and-15-m2/
[Steam Deck 64GB LCD]: https://store.steampowered.com/steamdeck
[GB-BXCEH-2955]: https://www.gigabyte.com/uk/Mini-PcBarebone/GB-BXCEH-2955-rev-10
[GB-BXCEH-2955 Review]: https://nucblog.net/2014/11/gigabyte-brix-2955u-review/
[QEMU]: https://www.qemu.org/

[Intel Core i9-9900K]: https://www.intel.com/content/www/us/en/products/sku/186605/intel-core-i99900k-processor-16m-cache-up-to-5-00-ghz/specifications.html
[Intel Xeon E-2176M]: https://ark.intel.com/content/www/us/en/ark/products/134867/intel-xeon-e-2176m-processor-12m-cache-up-to-4-40-ghz.html
[Intel Core i7-5557U]: https://www.intel.com/content/www/us/en/products/sku/84993/intel-core-i75557u-processor-4m-cache-up-to-3-40-ghz/specifications.html
[Intel Core i7-6770HQ]: https://ark.intel.com/content/www/us/en/ark/products/93341/intel-core-i7-6770hq-processor-6m-cache-up-to-3-50-ghz.html
[Intel Celeron 2955U]: https://www.intel.com/content/www/us/en/products/sku/75608/intel-celeron-processor-2955u-2m-cache-1-40-ghz/specifications.html
[AMD Ryzen 9 5950X]: https://www.amd.com/en/products/cpu/amd-ryzen-9-5950x
[AMD Ryzen 9 5900X]: https://www.amd.com/en/products/cpu/amd-ryzen-9-5900x
[AMD Ryzen 5 PRO 6650U]: https://www.amd.com/en/products/apu/amd-ryzen-5-pro-6650u
[AMD Ryzen Threadripper 3970X]: https://www.amd.com/en/support/cpu/amd-ryzen-processors/amd-ryzen-threadripper-processors/amd-ryzen-threadripper-3970x
[Intel Arc A770 16GB]: https://www.intel.com/content/www/us/en/products/sku/229151/intel-arc-a770-graphics-16gb/specifications.html
[Fighter RX 6800]: https://www.powercolor.com/product?id=1606212415
[Fighter RX 6700 XT]: https://www.powercolor.com/product?id=1612512944
[GeForce RTX 3090 GAMING OC]: https://www.gigabyte.com/uk/Graphics-Card/GV-N3090GAMING-OC-24GD#kf
[NVIDIA Quadro P2000 Max-Q]: https://www.nvidia.com/content/dam/en-zz/Solutions/design-visualization/productspage/quadro/quadro-desktop/quadro-pascal-p2000-data-sheet-us-nvidia-704443-r2-web.pdf
[NVIDIA T1000]: https://www.nvidia.com/content/dam/en-zz/Solutions/design-visualization/productspage/quadro/quadro-desktop/proviz-print-nvidia-T1000-datasheet-us-nvidia-1670054-r4-web.pdf
[NVIDIA T600]: https://www.nvidia.com/content/dam/en-zz/Solutions/design-visualization/productspage/quadro/quadro-desktop/proviz-print-nvidia-T600-datasheet-us-nvidia-1670029-r5-web.pdf
[NVIDIA T400]: https://www.nvidia.com/content/dam/en-zz/Solutions/design-visualization/productspage/quadro/quadro-desktop/nvidia-t400-datasheet-1987150-r3.pdf
[VirGL]: https://docs.mesa3d.org/drivers/virgl.html

[.github]: ./github/workflows
[home-manager]: ./home-manager
[nixos]: ./nixos
[nixos/_mixins]: ./nixos/_mixins
[home-manager/_mixins]: ./home-manager/_mixins
[flake.nix]: ./flake.nix

[Modern Unix]: ./home-manager/_mixins/console/default.nix
[micro]: [https://micro-editor.github.io/]
[sops-nix]: [https://github.com/Mic92/sops-nix]

[GNOME Install]: ./nixos/_mixins/desktop/gnome/defaul.nix
[MATE Install]: ./nixos/_mixins/desktop/mate/defaul.nix
[Pantheon Install]: ./nixos/_mixins/desktop/pantheon/default.nix
[GNOME Configuration]: ./home-manager/_mixins/desktop/gnome.nix
[MATE Configuration]: ./home-manager/_mixins/desktop/mate.nix
[Pantheon Configuration]: ./home-manager/_mixins/desktop/pantheon.nix
