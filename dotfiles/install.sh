#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

green() { echo -e "\033[32m✓ $*\033[0m"; }
blue()  { echo -e "\033[34m→ $*\033[0m"; }
red()   { echo -e "\033[31m✗ $*\033[0m"; }

# ── 1. Cài zsh ───────────────────────────────────────────────
if command -v zsh &>/dev/null; then
    green "zsh đã được cài ($(zsh --version | cut -d' ' -f2))"
else
    blue "Cài zsh..."
    sudo apt update -qq && sudo apt install -y zsh
    green "zsh đã cài xong"
fi

# ── 2. Cài Starship ──────────────────────────────────────────
if command -v starship &>/dev/null; then
    green "Starship đã được cài ($(starship --version | head -1))"
else
    blue "Cài Starship vào ~/.local/bin..."
    mkdir -p "$HOME/.local/bin"
    curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
    green "Starship đã cài xong"
fi

# ── 3. Link/copy config files ────────────────────────────────
blue "Symlink ~/.zshrc..."
[ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.bak" && echo "  (backup → ~/.zshrc.bak)"
ln -sf "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
green "~/.zshrc → $DOTFILES_DIR/zshrc"

blue "Symlink ~/.config/starship.toml..."
mkdir -p "$HOME/.config"
[ -f "$HOME/.config/starship.toml" ] && [ ! -L "$HOME/.config/starship.toml" ] && mv "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak" && echo "  (backup → ~/.config/starship.toml.bak)"
ln -sf "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
green "~/.config/starship.toml → $DOTFILES_DIR/config/starship.toml"

# ── 4. Đổi default shell sang zsh ───────────────────────────
ZSH_PATH="$(which zsh)"
CURRENT_SHELL="$(grep "^$USER" /etc/passwd | cut -d: -f7)"

if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
    green "Default shell đã là zsh"
else
    blue "Đổi default shell sang zsh..."
    sudo chsh -s "$ZSH_PATH" "$USER"
    green "Default shell → $ZSH_PATH"
fi

echo ""
green "Xong! Mở terminal mới để thấy Starship prompt."
