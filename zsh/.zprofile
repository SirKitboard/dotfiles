# ── Homebrew ──────────────────────────────────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Atuin ─────────────────────────────────────────────────────────────────────
# Only needed for script-based installs; Homebrew installs skip this file
[[ -f "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"
