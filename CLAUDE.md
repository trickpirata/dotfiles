# dotfiles

Personal shell/editor/git-UI config for macOS (Linux best-effort). Remote: `github.com/trickpirata/dotfiles`.

## Layout

- Repo root dotfiles (`.zshrc`, `.zprofile`, `.p10k.zsh`, `.vimrc`, `.gitignore`) → symlinked straight into `$HOME` by `bootstrap.sh` (`FILES_TO_LINK`).
- `config/<app>/...` → app configs that live outside `$HOME`'s root. Linked by the `APP_CONFIGS` table in `bootstrap.sh` (`"repo source|target"` pairs).
  - `config/lazygit/config.yml` → `~/Library/Application Support/lazygit/config.yml` on macOS (lazygit's default location there), `~/.config/lazygit/` on Linux.
  - `config/delta/catppuccin.gitconfig` → `~/.config/delta/catppuccin.gitconfig`.
- `bootstrap.sh` — installs brew/apt/dnf/pacman deps, Oh My Zsh, Powerlevel10k, backs up real files to `~/.dotfiles-backup/<timestamp>/`, then links.

## Adding a config

1. Root-level `$HOME` dotfile → add it at repo root and to `FILES_TO_LINK`.
2. Anything under `~/.config`, `~/Library/...`, etc. → put it in `config/<app>/` and add a pair to `APP_CONFIGS`. Branch on `$OS_FRIENDLY` if the path differs per OS.
3. New CLI dependency → add to the `brew install` line in `install_packages`.
4. Update the README file table (and Tooling/Roadmap if relevant).
5. `bash -n bootstrap.sh` to syntax-check. Don't run the full bootstrap to test — it installs software, may `chsh`, and moves existing files.

## Conventions / gotchas

- `bootstrap.sh` assumes the repo is cloned at `~/.dotfiles` (it `cd`s there). A working copy elsewhere is fine for editing, but links point at `~/.dotfiles`.
- Stow mode only kicks in if a top-level dir contains `.stow`, `.zshrc` or `.vimrc`. `config/` must never contain those, or bootstrap switches to `stow */`.
- delta config is loaded via `delta --config <file>` from the lazygit pager command, deliberately NOT through `~/.gitconfig` — keep it that way so plain `git` output is unaffected.
- Theme is Catppuccin **Frappe** everywhere (delta `syntax-theme`, palette hexes). Don't mix in Mocha/Macchiato hexes.
- `README.md` embeds an older, escaped copy of `bootstrap.sh`; the real script is the source of truth.
- Secrets never go in this repo (it is pushed to GitHub).
