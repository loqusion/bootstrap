# Bootstrap

Keeps track of installed packages, enabled systemd services, _selected_ `/etc`
configuration files (mostly diffs), bootloader entries, and `~/.config` files on
a per-machine basis. Currently supports Arch Linux and macOS.

THIS CODE IS BRITTLE AND UNSTABLE! USE AT YOUR OWN RISK!

## Installation

### Installing from USB installation medium (Arch Linux)

[Install Arch Linux via SSH](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH)

After enabling network functionality (e.g. `iwctl`) and setting a root password
with `passwd`, you can `ssh` into the machine and copy-paste the following:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/loqusion/bootstrap/main/liveinstall.sh)"
```

### After rebooting

For Arch, installs paru, packages, and system config files, and enables systemd services.

For macOS, installs Homebrew, Xcode Command Line Tools, and Homebrew packages.

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/loqusion/bootstrap/main/install.sh)"
```

### After loading a graphical environment

Installs the Dashlane browser extension for password management and authenticates
the GitHub CLI.

```sh
~/.local/share/bootstrap/auth.sh
```

## Dumping configuration

Stores a list of manually installed packages, a list of enabled systemd services,
and certain system-wide configuration files like those kept in `/etc`. Most of
the system-wide configuration is kept in `.patch` files to accommodate upstream changes.

```sh
~/.local/share/bootstrap/dump.sh
```
