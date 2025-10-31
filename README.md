# 🧠 Dotfiles

Personal configuration files for my development environments — streamlined, portable, and version‑controlled using **GNU Stow**.  
Tuned for productivity, minimalism, and consistency across macOS and Linux machines.

---

## 🧩 Overview

This repository contains the key configuration files that shape my command-line workflow:

| File | Description |
|------|--------------|
| `.zshrc` | Main Zsh configuration — sources plugins, aliases, and Powerlevel10k theme. |
| `.p10k.zsh` | Powerlevel10k prompt configuration (theme, segments, colors). |
| `.zprofile` | Login shell setup — exports PATHs and environment variables. |
| `.vimrc` | Vim configuration — sensible defaults, syntax highlighting, indentation. |
| `.gitignore` | Global Git ignore patterns. |

> ℹ️ **Note on Stow layout:** I currently keep dotfiles at the repo root. The bootstrap script supports both layouts:
> - **Root files** (this repo’s current state) → it will safely symlink them.
> - **Stow packages** (e.g., `zsh/.zshrc`, `vim/.vimrc`) → it will use `stow` if those package folders exist.

---

## ⚙️ Installation (Using GNU Stow)

### 1️⃣ Clone the repository
```bash
git clone https://github.com/trickpirata/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 2️⃣ Quick apply
If you’re keeping files at the repo root (as in this repo now), you can run:
```bash
./bootstrap.sh
```
This installs prerequisites (Zsh, Oh My Zsh, Powerlevel10k, Stow) and then safely links configs.

If you switch to a **Stow package layout** later (e.g., `zsh/.zshrc`, `vim/.vimrc`), you can apply specific packages:
```bash
stow -t "$HOME" zsh
stow -t "$HOME" vim
stow -t "$HOME" git
```

---

## 🚀 Bootstrap Setup

Automate the initial setup on a fresh system with a single command.  
This script installs core tools, clones the repo if needed, backs up any existing dotfiles, and applies symlinks (with Stow when packages are present).

Create a file named `bootstrap.sh` inside the repo with the following (already included in this download):

```bash
#!/usr/bin/env bash

set -euo pipefail

# ---------- Styling ----------
if command -v tput >/dev/null 2>&1; then
  tput colors >/dev/null 2>&1 && COLORS=$(tput colors) || COLORS=0
else
  COLORS=0
fi

if [ \"$COLORS\" -ge 8 ]; then
  BOLD=\"$(tput bold)\"; RESET=\"$(tput sgr0)\"
  BLUE=\"$(tput setaf 4)\"; GREEN=\"$(tput setaf 2)\"; YELLOW=\"$(tput setaf 3)\"; RED=\"$(tput setaf 1)\"
else
  BOLD=\"\"; RESET=\"\"; BLUE=\"\"; GREEN=\"\"; YELLOW=\"\"; RED=\"\"
fi

header() { echo \"${BOLD}${BLUE}==>${RESET} ${BOLD}$*${RESET}\"; }
info()   { echo \"${BLUE}i${RESET}  $*\"; }
ok()     { echo \"${GREEN}✔${RESET}  $*\"; }
warn()   { echo \"${YELLOW}⚠${RESET}  $*\"; }
err()    { echo \"${RED}✖${RESET}  $*\"; }

# ---------- Detect platform & package manager ----------
OS=\"$(uname -s)\"
PM=\"\"
case \"$OS\" in
  Darwin*) OS_FRIENDLY=\"macOS\"; PM=brew ;;
  Linux*)  OS_FRIENDLY=\"Linux\";;
  *)       OS_FRIENDLY=\"$OS\" ;;
esac

if [ -z \"$PM\" ]; then
  if command -v apt >/dev/null 2>&1;     then PM=apt;     fi
  if command -v dnf >/dev/null 2>&1;     then PM=dnf;     fi
  if command -v pacman >/dev/null 2>&1;  then PM=pacman;  fi
fi

header \"Bootstrapping on $OS_FRIENDLY\"

# ---------- Ensure package manager & core tools ----------
install_packages() {
  case \"$PM\" in
    brew)
      if ! command -v brew >/dev/null 2>&1; then
        header \"Installing Homebrew\"
        /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"
        # shellcheck disable=SC2016
        test -d /opt/homebrew && echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> \"$HOME/.zprofile\"
        test -d /opt/homebrew && eval \"$(/opt/homebrew/bin/brew shellenv)\"
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
      warn \"Unsupported package manager. Please install: git, stow, zsh, curl\"
      ;;
  esac
}

install_packages
ok \"Core tools present\"

# ---------- Oh My Zsh & Powerlevel10k ----------
if [ ! -d \"$HOME/.oh-my-zsh\" ]; then
  header \"Installing Oh My Zsh (unattended)\"
  export RUNZSH=no
  sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended
  ok \"Oh My Zsh installed\"
else
  info \"Oh My Zsh already installed\"
fi

THEME_DIR=\"${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k\"
if [ ! -d \"$THEME_DIR\" ]; then
  header \"Installing Powerlevel10k\"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k \"$THEME_DIR\"
  ok \"Powerlevel10k installed\"
else
  info \"Powerlevel10k already present\"
fi

# ---------- Clone repo if running stand‑alone ----------
if [ ! -d \"$HOME/.dotfiles\" ]; then
  header \"Cloning dotfiles repo\"
  git clone https://github.com/trickpirata/dotfiles.git \"$HOME/.dotfiles\"
fi

cd \"$HOME/.dotfiles\"

# ---------- Backup existing files ----------
timestamp=\"$(date +%Y%m%d-%H%M%S)\"
backup_dir=\"$HOME/.dotfiles-backup/$timestamp\"
mkdir -p \"$backup_dir\"

backup_if_needed() {
  local target=\"$1\"
  if [ -e \"$target\" ] && [ ! -L \"$target\" ]; then
    mv \"$target\" \"$backup_dir\"
    info \"Backed up $target -> $backup_dir/\"
  fi
}

FILES_TO_LINK=(
  .zshrc
  .zprofile
  .p10k.zsh
  .vimrc
  .gitignore
)

for f in \"${FILES_TO_LINK[@]}\"; do
  backup_if_needed \"$HOME/$f\"
done

# ---------- Stow if packages exist; else symlink root files ----------
use_stow=0
for d in *; do
  if [ -d \"$d\" ] && [ -e \"$d/.stow\" -o -e \"$d/.zshrc\" -o -e \"$d/.vimrc\" ]; then
    use_stow=1
    break
  fi
done

if command -v stow >/dev/null 2>&1 && [ \"$use_stow\" -eq 1 ]; then
  header \"Applying packages with GNU Stow\"
  stow -t \"$HOME\" */ 2>/dev/null || true
  ok \"Stow completed\"
else
  header \"Linking root‑level dotfiles\"
  for f in \"${FILES_TO_LINK[@]}\"; do
    if [ -e \"$f\" ]; then
      ln -sfn \"$PWD/$f\" \"$HOME/$f\"
      info \"Linked ~/$f\"
    fi
  done
  ok \"Symlinks created\"
fi

# ---------- Set default shell to zsh ----------
if [ \"$(basename \"$SHELL\")\" != \"zsh\" ]; then
  if command -v chsh >/dev/null 2>&1; then
    warn \"Changing your login shell to zsh (you may need to enter your password).\"
    chsh -s \"$(command -v zsh)\" || warn \"Could not change default shell automatically.\"
  else
    warn \"chsh not available; set your default shell to zsh manually.\"
  fi
fi

ok \"Bootstrap complete. Open a new terminal (or run 'exec zsh').\"
echo
echo \"Tip: If the Powerlevel10k wizard doesn't start automatically, run: p10k configure\"
```

Then run:
```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

This will:
- Install Homebrew/apt/dnf/pacman dependencies where available
- Install Zsh + Oh My Zsh + Powerlevel10k  
- Backup any existing dotfiles (non‑symlinks) to `~/.dotfiles-backup/<timestamp>/`
- Apply symlinks using **Stow** if package folders exist, otherwise link the root files

---

## 🧰 Tooling

- **Shell:** [Zsh](https://www.zsh.org) + [Oh My Zsh](https://ohmyz.sh) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Editor:** [Vim](https://www.vim.org)
- **Package Management:** [Homebrew](https://brew.sh) / apt / dnf / pacman
- **Symlink Management:** [GNU Stow](https://www.gnu.org/software/stow/)
- **Terminal:** iTerm2 / Alacritty (Catppuccin or Solarized themes)

---

## 🧬 Quick Tips

- Customize aliases/functions inside `.zshrc` under their respective sections.  
- Edit `.p10k.zsh` to adjust prompt appearance.  
- Re‑run `stow` after moving to a package layout (e.g., `zsh/.zshrc`).  
- Use branches (`mac`, `linux`, `work`, `personal`) for context‑specific setups.  

---

## 🧭 Roadmap

- [ ] Add configs for `lazygit`, `iterm2`

---

## 📜 License

MIT License © [Patrick Joseph D. Gorospe](https://github.com/trickpirata)
