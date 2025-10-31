#!/usr/bin/env bash
set -euo pipefail

# ---------- Styling ----------
if command -v tput >/dev/null 2>&1; then
  tput colors >/devnull 2>&1 && COLORS=$(tput colors) || COLORS=0
else
  COLORS=0
fi

if [ "$COLORS" -ge 8 ]; then
  BOLD="$(tput bold)"; RESET="$(tput sgr0)"
  BLUE="$(tput setaf 4)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"
else
  BOLD=""; RESET=""; BLUE=""; GREEN=""; YELLOW=""; RED=""
fi

header() { echo "${BOLD}${BLUE}==>${RESET} ${BOLD}$*${RESET}"; }
info()   { echo "${BLUE}i${RESET}  $*"; }
ok()     { echo "${GREEN}✔${RESET}  $*"; }
warn()   { echo "${YELLOW}⚠${RESET}  $*"; }
err()    { echo "${RED}✖${RESET}  $*"; }

# ---------- Detect platform & package manager ----------
OS="$(uname -s)"
PM=""
case "$OS" in
  Darwin*) OS_FRIENDLY="macOS"; PM=brew ;;
  Linux*)  OS_FRIENDLY="Linux" ;;
  *)       OS_FRIENDLY="$OS" ;;
esac

if [ -z "$PM" ]; then
  if command -v apt >/dev/null 2>&1;     then PM=apt;     fi
  if command -v dnf >/dev/null 2>&1;     then PM=dnf;     fi
  if command -v pacman >/dev/null 2>&1;  then PM=pacman;  fi
fi

header "Bootstrapping on $OS_FRIENDLY"

# ---------- Ensure package manager & core tools ----------
install_packages() {
  case "$PM" in
    brew)
      if ! command -v brew >/dev/null 2>&1; then
        header "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        test -d /opt/homebrew && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        test -d /opt/homebrew && eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
      brew update
      brew install git stow zsh >/dev/null || true
      ;;
    apt)
      sudo apt update -y
      sudo apt install -y git stow zsh curl
      ;;
    dnf)
      sudo dnf install -y git stow zsh curl
      ;;
    pacman)
      sudo pacman -Sy --noconfirm git stow zsh curl
      ;;
    *)
      warn "Unsupported package manager. Please install: git, stow, zsh, curl"
      ;;
  esac
}

install_packages
ok "Core tools present"

# ---------- Oh My Zsh & Powerlevel10k ----------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  header "Installing Oh My Zsh (unattended)"
  export RUNZSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  ok "Oh My Zsh installed"
else
  info "Oh My Zsh already installed"
fi

THEME_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$THEME_DIR" ]; then
  header "Installing Powerlevel10k"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k "$THEME_DIR"
  ok "Powerlevel10k installed"
else
  info "Powerlevel10k already present"
fi

# ---------- Clone repo if running stand‑alone ----------
if [ ! -d "$HOME/.dotfiles" ]; then
  header "Cloning dotfiles repo"
  git clone https://github.com/trickpirata/dotfiles.git "$HOME/.dotfiles"
fi

cd "$HOME/.dotfiles"

# ---------- Backup existing files ----------
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.dotfiles-backup/$timestamp"
mkdir -p "$backup_dir"

backup_if_needed() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$backup_dir"
    info "Backed up $target -> $backup_dir/"
  fi
}

FILES_TO_LINK=(
  .zshrc
  .zprofile
  .p10k.zsh
  .vimrc
  .gitignore
)

for f in "${FILES_TO_LINK[@]}"; do
  backup_if_needed "$HOME/$f"
done

# ---------- Stow if packages exist; else symlink root files ----------
use_stow=0
for d in *; do
  if [ -d "$d" ] && { [ -e "$d/.stow" ] || [ -e "$d/.zshrc" ] || [ -e "$d/.vimrc" ]; }; then
    use_stow=1
    break
  fi
done

if command -v stow >/dev/null 2>&1 && [ "$use_stow" -eq 1 ]; then
  header "Applying packages with GNU Stow"
  stow -t "$HOME" */ 2>/dev/null || true
  ok "Stow completed"
else
  header "Linking root‑level dotfiles"
  for f in "${FILES_TO_LINK[@]}"; do
    if [ -e "$f" ]; then
      ln -sfn "$PWD/$f" "$HOME/$f"
      info "Linked ~/$f"
    fi
  done
  ok "Symlinks created"
fi

# ---------- Set default shell to zsh ----------
if [ "$(basename "$SHELL")" != "zsh" ]; then
  if command -v chsh >/dev/null 2>&1; then
    warn "Changing your login shell to zsh (you may need to enter your password)."
    chsh -s "$(command -v zsh)" || warn "Could not change default shell automatically."
  else
    warn "chsh not available; set your default shell to zsh manually."
  fi
fi

ok "Bootstrap complete. Open a new terminal (or run 'exec zsh')."
echo
echo "Tip: If the Powerlevel10k wizard doesn't start automatically, run: p10k configure"
