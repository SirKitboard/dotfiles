# dotfiles

Adi's macOS developer environment. Run `install.sh` on a fresh Mac to get everything set up.

## What's included

| Area | Tool |
|------|------|
| Shell | zsh + [Oh My Zsh](https://ohmyz.sh) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| Terminal | iTerm2 |
| Prompt | Powerlevel10k (classic, NerdFont, dark) |
| Shell history | [Atuin](https://atuin.sh) (searchable, syncable) |
| Shell completions | [Carapace](https://carapace.sh) |
| `cd` replacement | [Zoxide](https://github.com/ajeetdsouza/zoxide) |
| Fuzzy finder | [fzf](https://github.com/junegunn/fzf) |
| Editor | Neovim ([LazyVim](https://lazyvim.github.io)) + VSCode / Cursor |
| Git | git + gh CLI + GitKraken / GitHub Desktop |
| Node | nvm (v24 default) |
| Python | pyenv (3.13.3 default) |
| Packages | Homebrew (see `Brewfile`) |
| Window manager | [Rectangle](https://rectangleapp.com) |
| Cloud | Cloudflare CLI (`cf`) |

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/sirkitboard/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles

# 2. Run the install script
./install.sh
```

The script is **idempotent** — safe to re-run. Existing files are backed up with a `.bak` suffix before being replaced with symlinks.

## What `install.sh` does

1. **Xcode CLT** — installs if missing (required for git, compilers)
2. **Homebrew** — installs if missing, then runs `brew bundle` from `Brewfile`
3. **Oh My Zsh** — installs if missing
4. **Powerlevel10k** — clones into oh-my-zsh custom themes
5. **Atuin** — installs the shell history daemon
6. **Symlinks** — links all config files from this repo into their expected locations
7. **VSCode** — links `settings.json` / `keybindings.json`, installs all extensions from `extensions.txt`
8. **macOS defaults** — applies sensible system preferences (key repeat, Finder, Dock, etc.)
9. **Node** — installs Node 24 via nvm and sets it as default
10. **Python** — installs Python 3.13.3 via pyenv and sets it as global

## File layout

```
dotfiles/
├── install.sh          # Bootstrap everything
├── Brewfile            # All Homebrew formulae + casks
├── zsh/
│   ├── .zshrc          # Main shell config
│   ├── .zprofile       # Login shell config (brew shellenv + atuin)
│   └── .p10k.zsh       # Powerlevel10k prompt config
├── git/
│   └── .gitconfig      # Git identity, merge/pull strategy, pager
├── ssh/
│   └── config          # SSH host aliases (no keys — add those manually)
├── nvim/               # LazyVim config → symlinked to ~/.config/nvim
│   ├── init.lua
│   └── lua/
│       ├── config/
│       │   ├── autocmds.lua
│       │   ├── keymaps.lua
│       │   ├── lazy.lua
│       │   └── options.lua
│       └── plugins/
│           └── example.lua
└── vscode/
    ├── settings.json       # VSCode user settings
    ├── keybindings.json    # VSCode custom keybindings
    └── extensions.txt      # List of extensions (one per line)
```

## Symlink map

| Source (this repo) | Destination |
|--------------------|-------------|
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.zprofile` | `~/.zprofile` |
| `zsh/.p10k.zsh` | `~/.p10k.zsh` |
| `git/.gitconfig` | `~/.gitconfig` |
| `ssh/config` | `~/.ssh/config` |
| `nvim/` | `~/.config/nvim` |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `vscode/keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` |

## After install — manual steps

These can't be automated:

- **SSH keys** — copy your keys into `~/.ssh/` and `chmod 600 ~/.ssh/id_*`
- **Atuin sync** — run `atuin login` to connect your history to the cloud
- **Sign in to apps** — Docker, GitHub Desktop, Tailscale, NordVPN, Google Drive, Discord
- **App Store** — Xcode (full), WireGuard (if not using the brew cask)
- **iTerm2 profile** — go to *Preferences → Profiles → Other Actions → Export JSON* and save to `iterm2/profile.json` in this repo. On a new machine: *Import JSON Profile* before first use.
- **Font** — the `font-meslo-lg-nerd-font` cask installs it; set it in iTerm2: *Preferences → Profiles → Text → Font → MesloLGS NF*

## Updating configs

Config files are symlinked, so edits in `~/.zshrc` etc. automatically reflect in this repo. To save changes:

```bash
cd ~/Projects/dotfiles
git add -p
git commit -m "update zshrc"
git push
```

## Keeping it fresh

To regenerate the VSCode extension list from your current install:

```bash
code --list-extensions > ~/Projects/dotfiles/vscode/extensions.txt
```

To regenerate the Brewfile from what's currently installed:

```bash
brew bundle dump --force --file=~/Projects/dotfiles/Brewfile
```

> Note: `brew bundle dump` will include all installed packages including dependencies. The hand-curated `Brewfile` in this repo only lists intentionally installed tools — prefer keeping it curated.
