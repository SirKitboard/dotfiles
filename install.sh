#!/usr/bin/env bash
set -uo pipefail   # no -e: we track failures ourselves and always finish

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  !${NC} $*"; }
error()   { echo -e "${RED}  ✗${NC} $*"; }
skip()    { echo -e "${BLUE}  ↩${NC} $*"; }
section() { echo -e "\n${GREEN}══ $* ══${NC}"; }

# ── Failure tracking ──────────────────────────────────────────────────────────
FAILURES=()
fail() { FAILURES+=("$1"); error "$1"; }

# Runs a command, tracks pass/fail under a label.
track() {
  local label="$1"; shift
  echo -e "${BLUE}  →${NC} $label..."
  echo -e "    ${YELLOW}\$${NC} $*"
  if "$@"; then
    info "$label"
  else
    fail "$label"
  fi
}

# ── Helpers ───────────────────────────────────────────────────────────────────
backup_and_link() {
  local src="$1" dst="$2" label="${3:-$(basename "$dst")}"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "Backing up $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  mkdir -p "$(dirname "$dst")"
  if ln -sf "$src" "$dst"; then
    info "Linked $label"
  else
    fail "Symlink $label"
  fi
}

prompt() {
  local var="$1" label="$2" default="${3:-}"
  local prompt_str
  [[ -n "$default" ]] && prompt_str="  $label [$default]: " || prompt_str="  $label: "
  read -r -p "$prompt_str" value
  [[ -z "$value" && -n "$default" ]] && value="$default"
  printf -v "$var" '%s' "$value"
}

# ── 1. Personal Configuration ─────────────────────────────────────────────────
section "Personal Configuration"
echo "  This info is written into your local config files only — not committed."
echo ""

EXISTING_GIT_NAME=$(git config --global user.name 2>/dev/null || true)
EXISTING_GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)

if [[ -n "$EXISTING_GIT_NAME" && -n "$EXISTING_GIT_EMAIL" ]]; then
  skip "Git identity already set ($EXISTING_GIT_NAME <$EXISTING_GIT_EMAIL>)"
  GIT_NAME=""
  GIT_EMAIL=""
else
  prompt GIT_NAME  "Full name (for git commits)"
  prompt GIT_EMAIL "Email (for git commits)"
fi

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
if xcode-select -p &>/dev/null; then
  skip "Xcode CLT already installed"
else
  info "Installing Xcode Command Line Tools..."
  if xcode-select --install 2>&1; then
    until xcode-select -p &>/dev/null; do sleep 5; done
    info "Xcode CLT installed"
  else
    fail "Xcode CLT install"
  fi
fi

# ── 3. Homebrew ───────────────────────────────────────────────────────────────
section "Homebrew"
if command -v brew &>/dev/null; then
  skip "Homebrew already installed — updating..."
  track "Homebrew update" brew update
else
  track "Homebrew install" \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ── 4. Homebrew Packages ──────────────────────────────────────────────────────
section "Homebrew Packages (Brewfile)"
warn "Make sure you are signed into the Mac App Store before continuing (required for mas/Xcode/iMovie etc.)"
read -r -p "  Press Enter when ready (or Ctrl+C to skip)..."

# brew bundle continues past individual failures; we capture the exit code
# and also parse output to surface which specific packages failed
BUNDLE_OUTPUT=$(brew bundle --file="$DOTFILES_DIR/Brewfile" --verbose 2>&1)
BUNDLE_EXIT=$?
echo "$BUNDLE_OUTPUT"
if [[ $BUNDLE_EXIT -ne 0 ]]; then
  # Extract failed package names from brew bundle output
  while IFS= read -r line; do
    if [[ "$line" =~ ^(Installing|Cask).*failed ]] || [[ "$line" =~ Error ]]; then
      fail "brew: $line"
    fi
  done <<< "$BUNDLE_OUTPUT"
  # Fallback if parsing found nothing
  [[ ${#FAILURES[@]} -eq 0 ]] && fail "brew bundle (check output above)"
fi

# ── 5. Oh My Zsh ─────────────────────────────────────────────────────────────
section "Oh My Zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  skip "Oh My Zsh already installed"
else
  track "Oh My Zsh install" \
    bash -c "RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

# ── 6. Powerlevel10k ──────────────────────────────────────────────────────────
section "Powerlevel10k"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  skip "Powerlevel10k already installed — pulling latest..."
  track "Powerlevel10k update" git -C "$P10K_DIR" pull --ff-only
else
  track "Powerlevel10k install" \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# ── 7. Atuin ─────────────────────────────────────────────────────────────────
section "Atuin"
if command -v atuin &>/dev/null || [[ -f "$HOME/.atuin/bin/atuin" ]]; then
  skip "Atuin already installed"
else
  track "Atuin install" \
    bash -c "bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)"
fi

# ── 8. Dotfile Symlinks ───────────────────────────────────────────────────────
section "Dotfile Symlinks"

backup_and_link "$DOTFILES_DIR/zsh/.zshrc"             "$HOME/.zshrc"            ".zshrc"
backup_and_link "$DOTFILES_DIR/zsh/.zprofile"          "$HOME/.zprofile"         ".zprofile"
backup_and_link "$DOTFILES_DIR/zsh/.p10k.zsh"          "$HOME/.p10k.zsh"         ".p10k.zsh"
backup_and_link "$DOTFILES_DIR/git/.gitconfig"         "$HOME/.gitconfig"        ".gitconfig"
backup_and_link "$DOTFILES_DIR/nvim"                   "$HOME/.config/nvim"      "nvim config"
backup_and_link "$DOTFILES_DIR/claude/settings.json"   "$HOME/.claude/settings.json" "claude settings"

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
backup_and_link "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config" "ssh config"
chmod 600 "$HOME/.ssh/config"

# ── Apply personal config values ──────────────────────────────────────────────
if [[ -n "$GIT_NAME" ]];  then track "git user.name"  git config --global user.name  "$GIT_NAME";  fi
if [[ -n "$GIT_EMAIL" ]]; then track "git user.email" git config --global user.email "$GIT_EMAIL"; fi

SSH_CONFIG="$HOME/.ssh/config"
for i in 1 2; do
  local_alias="SSH_HOST_${i}_ALIAS"; local_host="SSH_HOST_${i}_HOSTNAME"; local_user="SSH_HOST_${i}_USER"
  alias_val="${!local_alias:-}"; host_val="${!local_host:-}"; user_val="${!local_user:-}"
  if [[ -n "$alias_val" && -n "$host_val" ]]; then
    if grep -q "^Host $alias_val$" "$SSH_CONFIG" 2>/dev/null; then
      skip "SSH host '$alias_val' already in config"
    else
      printf '\nHost %s\n  HostName %s\n  User %s\n' "$alias_val" "$host_val" "$user_val" >> "$SSH_CONFIG"
      info "SSH host '$alias_val' added"
    fi
  fi
done

# ── 9. VSCode ────────────────────────────────────────────────────────────────
section "VSCode Settings & Extensions"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
if command -v code &>/dev/null || [[ -d "/Applications/Visual Studio Code.app" ]]; then
  mkdir -p "$VSCODE_USER"
  backup_and_link "$DOTFILES_DIR/vscode/settings.json"    "$VSCODE_USER/settings.json"    "vscode settings"
  backup_and_link "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER/keybindings.json" "vscode keybindings"

  while IFS= read -r ext; do
    [[ -z "$ext" ]] && continue
    if code --list-extensions 2>/dev/null | grep -qi "^${ext}$"; then
      skip "VSCode ext: $ext (already installed)"
    else
      track "VSCode ext: $ext" code --install-extension "$ext" --force
    fi
  done < "$DOTFILES_DIR/vscode/extensions.txt"
else
  warn "VSCode not found — skipping"
fi

# ── 10. macOS Defaults ───────────────────────────────────────────────────────
section "macOS Defaults"
track "Keyboard: faster key repeat"   defaults write NSGlobalDomain KeyRepeat -int 2
track "Keyboard: initial key repeat"  defaults write NSGlobalDomain InitialKeyRepeat -int 15
track "Finder: show extensions"       defaults write NSGlobalDomain AppleShowAllExtensions -bool true
track "Finder: show hidden files"     defaults write com.apple.finder AppleShowAllFiles -bool true
track "Finder: show path bar"         defaults write com.apple.finder ShowPathbar -bool true
track "Dock: auto-hide"               defaults write com.apple.dock autohide -bool true
track "Dock: scale minimize"          defaults write com.apple.dock mineffect -string "scale"
track "Screenshots: save to Desktop"  defaults write com.apple.screencapture location -string "$HOME/Desktop"
track "Trackpad: tap to click"        defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
track "Rectangle: launch on login"    defaults write com.knollsoft.Rectangle launchOnLogin -bool true
track "Rectangle: allow any shortcut" defaults write com.knollsoft.Rectangle allowAnyShortcut -bool true
for app in "Finder" "Dock" "SystemUIServer"; do killall "$app" &>/dev/null || true; done

# ── 11. Node & Python ────────────────────────────────────────────────────────
section "Node (nvm)"
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh"
if command -v nvm &>/dev/null; then
  if nvm ls 24 &>/dev/null | grep -q "v24"; then
    skip "Node 24 already installed"
  else
    track "Node 24 install" nvm install 24
  fi
  track "Node 24 set default" nvm alias default 24

  for pkg in "@google/gemini-cli" "puppeteer-core" "cf"; do
    if npm list -g --depth=0 2>/dev/null | grep -q "${pkg##*/}"; then
      skip "npm: $pkg (already installed) — updating..."
      track "npm update: $pkg" npm install -g "$pkg"
    else
      track "npm install: $pkg" npm install -g "$pkg"
    fi
  done
else
  fail "nvm not available — run 'nvm install 24' after restarting terminal"
fi

section "Python (pyenv)"
if command -v pyenv &>/dev/null; then
  track "Python 3.13.3 install" pyenv install 3.13.3 --skip-existing
  track "Python 3.13.3 set global" pyenv global 3.13.3
else
  fail "pyenv not available — run 'pyenv install 3.13.3 && pyenv global 3.13.3' after restarting"
fi

# ── 12. Syncthing ────────────────────────────────────────────────────────────
section "Syncthing"
mkdir -p "$HOME/Sync/secrets"
info "~/Sync structure ready"

if [[ -f "$HOME/Sync/link-saves.sh" ]]; then
  track "Game save symlinks" bash "$HOME/Sync/link-saves.sh"
else
  warn "~/Sync/link-saves.sh not found — run it manually after Syncthing connects"
fi

info "Launch Syncthing from Applications to finish device pairing"

# ── 13. Optional Apps ────────────────────────────────────────────────────────
section "Optional Apps"
prompt_install_cask() {
  local cask="$1" label="$2"
  read -r -p "  Install $label? [y/N] " reply
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    track "Optional: $label" brew install --cask "$cask"
  else
    skip "$label"
  fi
}
prompt_install_cask "ollama"             "Ollama (local LLM runner)"
prompt_install_cask "epic-games"         "Epic Games Launcher"
prompt_install_cask "altserver"          "AltServer (iOS sideloading)"
prompt_install_cask "fontforge"          "FontForge (font editor)"
prompt_install_cask "unraid-usb-creator" "Unraid USB Creator"

# ── 14. CLI Auth ──────────────────────────────────────────────────────────────
section "CLI Auth"

if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    skip "GitHub CLI already authenticated"
  else
    track "GitHub CLI login" gh auth login
  fi
fi

if command -v cf &>/dev/null; then
  if cf whoami &>/dev/null 2>&1; then
    skip "Cloudflare CLI already authenticated"
  else
    if track "Cloudflare CLI login" cf login; then
      mkdir -p "$HOME/.config/cf/completions"
      track "Cloudflare CLI completions" \
        bash -c "cf completion zsh > \"$HOME/.config/cf/completions/_cf.zsh\""
    fi
  fi
fi

ATUIN_BIN="$HOME/.atuin/bin/atuin"
ATUIN_CMD=$(command -v atuin 2>/dev/null || echo "$ATUIN_BIN")
if [[ -x "$ATUIN_CMD" ]]; then
  if "$ATUIN_CMD" account info &>/dev/null 2>&1; then
    skip "Atuin already authenticated"
  else
    track "Atuin login" "$ATUIN_CMD" login
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
section "Summary"
echo ""
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  info "All steps completed successfully."
else
  error "${#FAILURES[@]} step(s) failed:"
  for f in "${FAILURES[@]}"; do
    echo -e "    ${RED}✗${NC} $f"
  done
  echo ""
  warn "Re-run install.sh to retry, or fix the above manually."
fi

echo ""
info "Manual steps remaining:"
echo "  • Generate SSH key: ssh-keygen -t ed25519 -C "your@email.com"
  •   Then add to GitHub: gh auth login (handles this) or paste ~/.ssh/id_ed25519.pub
  •   And add to any servers: ssh-copy-id user@host"
echo "  • iTerm2: Preferences → Profiles → Text → Font → MesloLGS NF"
echo "  • Sign in: Docker, NordVPN, Tailscale, Google Drive, GitHub Desktop,"
echo "             GitKraken, Spotify, Discord, Logi Options+"
echo "  • Syncthing: open app → add remote device → share ~/Sync folder"
echo "  • Neovim: run 'nvim' once to trigger lazy.nvim plugin install"
echo ""
