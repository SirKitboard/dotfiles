#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[dotfiles]${NC} $*"; }
warn()    { echo -e "${YELLOW}[dotfiles]${NC} $*"; }
error()   { echo -e "${RED}[dotfiles]${NC} $*" >&2; }
section() { echo -e "\n${GREEN}══ $* ══${NC}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
backup_and_link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "Backing up existing $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  info "Linked $dst → $src"
}

prompt() {
  local var="$1" label="$2" default="${3:-}"
  local prompt_str
  if [[ -n "$default" ]]; then
    prompt_str="  $label [$default]: "
  else
    prompt_str="  $label: "
  fi
  read -r -p "$prompt_str" value
  if [[ -z "$value" && -n "$default" ]]; then
    value="$default"
  fi
  printf -v "$var" '%s' "$value"
}

# ── 1. Personal Configuration ─────────────────────────────────────────────────
section "Personal Configuration"
echo "  This info is written into your local config files only — not committed."
echo ""

prompt GIT_NAME  "Full name (for git commits)"
prompt GIT_EMAIL "Email (for git commits)"

echo ""
echo "  SSH hosts (leave blank to skip):"
prompt SSH_HOST_1_ALIAS "  Host alias (e.g. homeserver)"
if [[ -n "$SSH_HOST_1_ALIAS" ]]; then
  prompt SSH_HOST_1_HOSTNAME "  HostName/IP for $SSH_HOST_1_ALIAS"
  prompt SSH_HOST_1_USER     "  User for $SSH_HOST_1_ALIAS" "root"
fi
prompt SSH_HOST_2_ALIAS "  Second host alias (leave blank to skip)"
if [[ -n "$SSH_HOST_2_ALIAS" ]]; then
  prompt SSH_HOST_2_HOSTNAME "  HostName/IP for $SSH_HOST_2_ALIAS"
  prompt SSH_HOST_2_USER     "  User for $SSH_HOST_2_ALIAS" "root"
fi

# ── 2. Xcode Command Line Tools ───────────────────────────────────────────────
section "Xcode Command Line Tools"
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  # Wait for the user to finish the GUI installation before continuing
  until xcode-select -p &>/dev/null; do sleep 5; done
else
  info "Xcode CLT already installed"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
section "Homebrew"
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  info "Homebrew already installed — updating..."
  brew update
fi

# ── 3. Homebrew Packages ──────────────────────────────────────────────────────
section "Homebrew Packages (Brewfile)"
warn "Make sure you are signed into the Mac App Store before continuing (required for mas/Xcode/iMovie etc.)"
read -r -p "  Press Enter when ready (or Ctrl+C to skip and run manually later)..."
brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "Some packages may have failed — review output above"

# ── 4. Oh My Zsh ─────────────────────────────────────────────────────────────
section "Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  info "Oh My Zsh already installed"
fi

# ── 5. Powerlevel10k ──────────────────────────────────────────────────────────
section "Powerlevel10k"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
  info "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  info "Powerlevel10k already installed"
fi

# ── 6. Atuin ─────────────────────────────────────────────────────────────────
section "Atuin"
if ! command -v atuin &>/dev/null && [[ ! -f "$HOME/.atuin/bin/atuin" ]]; then
  info "Installing Atuin..."
  bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
else
  info "Atuin already installed"
fi

# ── 7. Dotfile Symlinks ───────────────────────────────────────────────────────
section "Dotfile Symlinks"

# ZSH
backup_and_link "$DOTFILES_DIR/zsh/.zshrc"   "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"
backup_and_link "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

# Git
backup_and_link "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

# SSH config (not keys — generate/copy those manually)
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
backup_and_link "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

# Neovim
backup_and_link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

# Claude Code
backup_and_link "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

# ── Apply personal config values ──────────────────────────────────────────────

# Git identity
if [[ -n "$GIT_NAME" ]]; then
  git config --global user.name "$GIT_NAME"
  info "Git user.name set to '$GIT_NAME'"
fi
if [[ -n "$GIT_EMAIL" ]]; then
  git config --global user.email "$GIT_EMAIL"
  info "Git user.email set to '$GIT_EMAIL'"
fi

# SSH hosts — append to ssh/config (the symlink target)
SSH_CONFIG="$HOME/.ssh/config"
if [[ -n "$SSH_HOST_1_ALIAS" && -n "$SSH_HOST_1_HOSTNAME" ]]; then
  # Remove any previous entry with the same alias to stay idempotent
  if grep -q "^Host $SSH_HOST_1_ALIAS$" "$SSH_CONFIG" 2>/dev/null; then
    warn "SSH host '$SSH_HOST_1_ALIAS' already in config — skipping"
  else
    {
      echo ""
      echo "Host $SSH_HOST_1_ALIAS"
      echo "  HostName $SSH_HOST_1_HOSTNAME"
      echo "  User $SSH_HOST_1_USER"
    } >> "$SSH_CONFIG"
    info "SSH host '$SSH_HOST_1_ALIAS' added"
  fi
fi
if [[ -n "$SSH_HOST_2_ALIAS" && -n "$SSH_HOST_2_HOSTNAME" ]]; then
  if grep -q "^Host $SSH_HOST_2_ALIAS$" "$SSH_CONFIG" 2>/dev/null; then
    warn "SSH host '$SSH_HOST_2_ALIAS' already in config — skipping"
  else
    {
      echo ""
      echo "Host $SSH_HOST_2_ALIAS"
      echo "  HostName $SSH_HOST_2_HOSTNAME"
      echo "  User $SSH_HOST_2_USER"
    } >> "$SSH_CONFIG"
    info "SSH host '$SSH_HOST_2_ALIAS' added"
  fi
fi

# ── 8. VSCode Settings ────────────────────────────────────────────────────────
section "VSCode Settings"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
if command -v code &>/dev/null || [[ -d "/Applications/Visual Studio Code.app" ]]; then
  mkdir -p "$VSCODE_USER"
  backup_and_link "$DOTFILES_DIR/vscode/settings.json"    "$VSCODE_USER/settings.json"
  backup_and_link "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER/keybindings.json"

  section "VSCode Extensions"
  while IFS= read -r ext; do
    code --install-extension "$ext" --force 2>/dev/null || warn "Could not install extension: $ext"
  done < "$DOTFILES_DIR/vscode/extensions.txt"
else
  warn "VSCode not found — skipping settings and extensions"
fi

# ── 9. macOS System Preferences ───────────────────────────────────────────────
section "macOS Defaults"

# Keyboard: faster key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Finder: show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Dock: auto-hide
defaults write com.apple.dock autohide -bool true

# Dock: minimize effect = scale (faster)
defaults write com.apple.dock mineffect -string "scale"

# Screenshots: save to ~/Desktop
defaults write com.apple.screencapture location -string "$HOME/Desktop"

# Trackpad: tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Rectangle: launch on login (already set in prefs, just ensuring)
defaults write com.knollsoft.Rectangle launchOnLogin -bool true
defaults write com.knollsoft.Rectangle allowAnyShortcut -bool true

# Kill affected apps
for app in "Finder" "Dock" "SystemUIServer"; do
  killall "$app" &>/dev/null || true
done

info "macOS defaults applied"

# ── 10. Node / Python Versions ────────────────────────────────────────────────
section "Node (nvm)"
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh"
if command -v nvm &>/dev/null; then
  nvm install 24 && nvm alias default 24
  info "Node v24 installed and set as default"

  info "Installing global npm packages..."
  npm install -g @google/gemini-cli
  npm install -g puppeteer-core
else
  warn "nvm not available in this shell — run 'nvm install 24' after restarting your terminal"
fi

section "Python (pyenv)"
if command -v pyenv &>/dev/null; then
  pyenv install 3.13.3 --skip-existing
  pyenv global 3.13.3
  info "Python 3.13.3 set as global"
else
  warn "pyenv not available — run 'pyenv install 3.13.3 && pyenv global 3.13.3' after restarting"
fi

# ── 11. Syncthing (saves + secrets) ──────────────────────────────────────────
section "Syncthing"

SYNC_DIR="$HOME/Sync"
SECRETS_DIR="$SYNC_DIR/secrets"
SAVES_DIR="$SYNC_DIR/saves"

# Create the Sync directory structure
mkdir -p "$SECRETS_DIR"
mkdir -p "$SAVES_DIR/pokemon-infinite-fusion"
info "Created $SYNC_DIR structure"

# Pokemon Infinite Fusion — saves live in Wine's AppData
FUSION_SAVE_SRC="$HOME/.wine/drive_c/users/$USER/AppData/Roaming/infinitefusion"
FUSION_SAVE_DST="$SAVES_DIR/pokemon-infinite-fusion"

if [[ -d "$FUSION_SAVE_SRC" && ! -L "$FUSION_SAVE_SRC" ]]; then
  info "Migrating Infinite Fusion saves to $FUSION_SAVE_DST..."
  cp -r "$FUSION_SAVE_SRC/." "$FUSION_SAVE_DST/"
  rm -rf "$FUSION_SAVE_SRC"
  ln -sf "$FUSION_SAVE_DST" "$FUSION_SAVE_SRC"
  info "Infinite Fusion saves migrated and symlinked"
elif [[ ! -e "$FUSION_SAVE_SRC" ]]; then
  # Fresh install — Wine hasn't created the dir yet, pre-create the symlink
  mkdir -p "$(dirname "$FUSION_SAVE_SRC")"
  ln -sf "$FUSION_SAVE_DST" "$FUSION_SAVE_SRC"
  info "Infinite Fusion save symlink created (game not yet run)"
else
  info "Infinite Fusion save symlink already in place"
fi

info "Syncthing installed — launch it from Applications to finish setup"
warn "In the Syncthing UI: add your other device and share the '$SYNC_DIR' folder"
warn "Make sure to set the folder path to $SYNC_DIR on both machines"

# ── 12. Optional Apps ────────────────────────────────────────────────────────
section "Optional Apps"

prompt_install_cask() {
  local cask="$1" label="$2"
  read -r -p "  Install $label? [y/N] " reply
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    brew install --cask "$cask" && info "$label installed" || warn "Failed to install $label"
  else
    info "Skipping $label"
  fi
}

prompt_install_cask "ollama"             "Ollama (local LLM runner)"
prompt_install_cask "epic-games"         "Epic Games Launcher"
prompt_install_cask "altserver"          "AltServer (iOS sideloading)"
prompt_install_cask "fontforge"          "FontForge (font editor)"
prompt_install_cask "unraid-usb-creator" "Unraid USB Creator"

# ── 12. CLI Auth ─────────────────────────────────────────────────────────────
section "CLI Auth & Post-install Setup"

# GitHub CLI
if command -v gh &>/dev/null; then
  if ! gh auth status &>/dev/null; then
    info "Logging into GitHub CLI..."
    gh auth login
  else
    info "GitHub CLI already authenticated"
  fi
fi

# Cloudflare CLI
if command -v cf &>/dev/null; then
  if ! cf whoami &>/dev/null 2>&1; then
    info "Logging into Cloudflare CLI..."
    cf login
    # Generate zsh completions after login
    mkdir -p "$HOME/.config/cf/completions"
    cf completion zsh > "$HOME/.config/cf/completions/_cf.zsh"
    info "Cloudflare CLI completions written to ~/.config/cf/completions/_cf.zsh"
  else
    info "Cloudflare CLI already authenticated"
  fi
fi

# Atuin
if command -v atuin &>/dev/null || [[ -f "$HOME/.atuin/bin/atuin" ]]; then
  if ! atuin account info &>/dev/null 2>&1; then
    info "Logging into Atuin (shell history sync)..."
    "$HOME/.atuin/bin/atuin" login 2>/dev/null || atuin login
  else
    info "Atuin already authenticated"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
section "All done!"
echo ""
info "Automated setup complete. A few things need manual attention:"
echo ""
echo "  ── SSH ──────────────────────────────────────────────────────────"
echo "  Copy your SSH keys to ~/.ssh/ then run:"
echo "    chmod 600 ~/.ssh/id_*"
echo "    ssh-add ~/.ssh/id_rsa"
echo ""
echo "  ── Terminal ─────────────────────────────────────────────────────"
echo "  Restart your terminal, then:"
echo "    source ~/.zshrc"
echo "    p10k configure    # only if you want to redo the prompt wizard"
echo ""
echo "  In iTerm2: Preferences → Profiles → Text → Font → set 'MesloLGS NF'"
echo "  (Export your profile: Profiles → Other Actions → Export JSON → save to iterm2/profile.json)"
echo ""
echo "  ── Apps to sign into ────────────────────────────────────────────"
echo "  • Docker Desktop  — open app and sign in to Docker Hub"
echo "  • NordVPN         — open app and log in"
echo "  • Tailscale       — open app and authenticate"
echo "  • Google Drive    — open app and sign in"
echo "  • GitHub Desktop  — open app → File → Options → Accounts"
echo "  • GitKraken       — open app and sign in"
echo "  • Spotify         — open app and sign in"
echo "  • Discord         — open app and sign in"
echo "  • Logi Options+   — open app and pair your devices"
echo ""
echo "  ── App Store (install manually) ─────────────────────────────────"
echo "  • Xcode (full IDE)"
echo "  • WireGuard (if the brew cask didn't install correctly)"
echo ""
echo "  ── Neovim ───────────────────────────────────────────────────────"
echo "  First launch will auto-install plugins via lazy.nvim:"
echo "    nvim"
echo ""
