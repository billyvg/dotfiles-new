#!/usr/bin/env bash
#
# Entrypoint for `coder dotfiles`, and for manual use on any macOS/Linux box.
#
#   ./install.sh                 full install
#   ./install.sh --links-only    just re-link configs (fast, no packages)
#   ./install.sh --no-packages   links + post-install, skip apt/brew
#
# Idempotent: safe to re-run. Existing files are backed up to <file>.bak.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES

# shellcheck source=lib/os.sh
source "$DOTFILES/lib/os.sh"
# shellcheck source=lib/packages.sh
source "$DOTFILES/lib/packages.sh"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

DO_PACKAGES=1
DO_POST=1
for arg in "$@"; do
  case "$arg" in
    --links-only)  DO_PACKAGES=0; DO_POST=0 ;;
    --no-packages) DO_PACKAGES=0 ;;
    -h|--help)     sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             die "unknown argument: $arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
if [[ $DO_PACKAGES -eq 1 ]]; then
  info "detected OS: $OS$(is_coder && printf ' (coder workspace)')"
  # Each phase is soft: a package failure must not stop us from linking configs.
  soft "apt packages" install_apt_packages
  soft "homebrew"     install_homebrew
  soft "brew bundle"  run_brew_bundle
else
  skip "skipping package installation"
fi

# ---------------------------------------------------------------------------
# 2. Symlink home files
# ---------------------------------------------------------------------------
info "linking home files"

# Everything in home/ except the OS-suffixed variants, which are handled below.
while IFS= read -r -d '' file; do
  base="$(basename "$file")"
  case "$base" in
    *.darwin|*.linux) continue ;;
  esac
  link "$file" "$HOME/$base"
done < <(find "$DOTFILES/home" -maxdepth 1 -type f -print0)

# OS-specific fragments get a stable name the shared configs can source.
link "$DOTFILES/home/.zshrc.$OS"     "$HOME/.zshrc.os"
link "$DOTFILES/home/.gitconfig.$OS" "$HOME/.gitconfig.os"

# ---------------------------------------------------------------------------
# 3. Symlink XDG config dirs
# ---------------------------------------------------------------------------
info "linking ~/.config"

# config/        — everything, every platform.
# config.darwin/ — macOS only; config.linux/ — Linux only. Same `.darwin` /
# `.linux` suffix convention as home/ and the Brewfiles. The OS directory is
# linked second so that if both define the same app, the platform-specific one
# wins (link() backs the first one up rather than silently dropping it).
for base in "$DOTFILES/config" "$DOTFILES/config.$OS"; do
  [[ -d "$base" ]] || continue
  for dir in "$base"/*/; do
    [[ -d "$dir" ]] || continue
    link "${dir%/}" "$XDG_CONFIG_HOME/$(basename "${dir%/}")"
  done
done

# ---------------------------------------------------------------------------
# 4. Post-install
# ---------------------------------------------------------------------------
if [[ $DO_POST -eq 0 ]]; then
  skip "skipping post-install"
  ok "done"
  exit 0
fi

info "post-install"

# Untracked escape hatches — create empty so the `source` guards are cheap and
# so there's an obvious place to put machine-specific config and secrets.
for f in "$HOME/.zshrc.local" "$HOME/.gitconfig.local"; do
  [[ -e "$f" ]] || { touch "$f"; ok "created $(shorten "$f")"; }
done

# antidote (zsh plugin manager)
if [[ ! -d "$HOME/.antidote" ]]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  ok "antidote"
else
  skip "antidote present"
fi

# tmux plugin manager — .tmux.conf's `run` line needs this to exist first.
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  ok "tpm"
  # Install the plugins non-interactively so a fresh box doesn't need <prefix>+I.
  if with_timeout 300 "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1; then
    ok "tmux plugins"
  else
    warn "tmux plugin install failed; run <prefix>+I inside tmux"
  fi
else
  skip "tpm present"
fi

# bat theme cache — the Catppuccin themes are symlinked in via config/bat.
if has bat; then
  if bat cache --build >/dev/null 2>&1; then ok "bat theme cache"; else warn "bat cache --build failed"; fi
elif has batcat; then
  # Debian ships bat as batcat; give ourselves the normal name.
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  ok "linked batcat -> ~/.local/bin/bat"
fi

# gh extensions (not expressible in a Brewfile)
if has gh && gh auth status >/dev/null 2>&1; then
  for ext in meiji163/gh-notify seachicken/gh-poi; do
    if gh extension list 2>/dev/null | grep -q "${ext##*/}"; then
      skip "gh ext ${ext##*/} present"
    else
      if gh extension install "$ext" >/dev/null 2>&1; then
        ok "gh ext ${ext##*/}"
      else
        warn "gh ext $ext failed"
      fi
    fi
  done
else
  skip "gh not authenticated; skipping extensions"
fi

# Default shell. chsh often fails in a container (no PAM, user not in
# /etc/passwd as expected) — that's fine, Coder templates usually set the shell
# themselves, so warn rather than fail.
if has zsh; then
  zsh_path="$(command -v zsh)"
  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    grep -qxF "$zsh_path" /etc/shells 2>/dev/null \
      || { can_sudo && echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null; } 2>/dev/null || true
    if chsh -s "$zsh_path" >/dev/null 2>&1; then
      ok "default shell -> zsh"
    else
      warn "could not chsh to $zsh_path; set the shell in your Coder template instead"
    fi
  else
    skip "shell already zsh"
  fi
fi

# Neovim: sync plugins headlessly so the first real launch isn't a build wait.
if has nvim; then
  nvim_ver="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  if [[ "$(printf '%s\n0.12\n' "$nvim_ver" | sort -V | head -1)" != "0.12" ]]; then
    warn "nvim $nvim_ver is too old for vim.pack (needs >= 0.12); skipping plugin sync"
  else
    info "syncing neovim plugins (first run builds treesitter + blink.cmp)"
    # vim.pack.add() in init.lua installs anything missing at startup; the
    # update call then pulls the rest forward. 20min cap because a cold run
    # compiles every treesitter parser and cargo-builds blink.cmp.
    if with_timeout 1200 nvim --headless \
         "+lua pcall(vim.pack.update, nil, { force = true })" +qa >/dev/null 2>&1; then
      ok "neovim plugins"
    else
      warn "neovim plugin sync did not finish; open nvim and let it complete"
    fi
  fi
fi

ok "done"
if is_linux; then
  printf '\n%s\n' "Start a new shell (or run: exec zsh) to pick everything up."
fi
