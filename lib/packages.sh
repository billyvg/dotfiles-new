#!/usr/bin/env bash
# Package installation: apt (Linux base) and Homebrew (both platforms).
# Sourced by install.sh.

# --- apt -------------------------------------------------------------------
install_apt_packages() {
  is_linux || return 0
  has apt-get || { warn "no apt-get; skipping base packages"; return 0; }

  if ! can_sudo; then
    warn "no passwordless sudo; skipping apt packages"
    warn "install these yourself (or bake them into the Coder image):"
    warn "  $(read_package_list "$DOTFILES/apt-packages.txt" | tr '\n' ' ')"
    return 0
  fi

  local pkgs
  mapfile -t pkgs < <(read_package_list "$DOTFILES/apt-packages.txt")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0

  # Only install what's actually missing — keeps re-runs fast.
  local missing=()
  local p
  for p in "${pkgs[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$" \
      || missing+=("$p")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    skip "all apt packages present"
    return 0
  fi

  info "installing ${#missing[@]} apt package(s): ${missing[*]}"
  $SUDO apt-get update -qq || { warn "apt-get update failed"; return 1; }
  if ! DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq \
       --no-install-recommends "${missing[@]}"; then
    return 1
  fi
  ok "apt packages installed"
}

# Read a package list file: strip comments and blanks.
read_package_list() {
  [[ -f "$1" ]] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true
}

# --- Homebrew --------------------------------------------------------------
brew_prefix() {
  if is_darwin; then
    [[ -x /opt/homebrew/bin/brew ]] && { echo /opt/homebrew; return; }
    echo /usr/local
  else
    [[ -d /home/linuxbrew/.linuxbrew ]] && { echo /home/linuxbrew/.linuxbrew; return; }
    echo "$HOME/.linuxbrew"
  fi
}

load_brew() {
  local prefix
  prefix="$(brew_prefix)"
  if [[ -x "$prefix/bin/brew" ]]; then
    eval "$("$prefix/bin/brew" shellenv)"
    return 0
  fi
  has brew
}

install_homebrew() {
  if load_brew; then
    skip "homebrew present ($(brew --version | head -1))"
    return 0
  fi

  # On Linux, brew needs a compiler toolchain and either root or a writable
  # prefix. If we can't sudo, install into ~/.linuxbrew instead of failing.
  if is_linux && ! can_sudo; then
    info "installing homebrew to \$HOME (no sudo available)"
    git clone --depth=1 https://github.com/Homebrew/brew "$HOME/.linuxbrew/Homebrew" || return 1
    mkdir -p "$HOME/.linuxbrew/bin"
    ln -sf "$HOME/.linuxbrew/Homebrew/bin/brew" "$HOME/.linuxbrew/bin/brew"
  else
    info "installing homebrew"
    local installer
    installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || { warn "could not fetch the homebrew installer"; return 1; }
    NONINTERACTIVE=1 /bin/bash -c "$installer" || return 1
  fi

  if ! load_brew; then
    warn "homebrew install finished but brew is not on PATH"
    return 1
  fi
  ok "homebrew installed at $(brew --prefix)"
}

run_brew_bundle() {
  load_brew || { warn "brew unavailable; skipping bundle"; return 0; }

  local files=("$DOTFILES/Brewfile")
  if is_darwin; then
    files+=("$DOTFILES/Brewfile.darwin")
  else
    files+=("$DOTFILES/Brewfile.linux")
  fi

  local f
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    # An all-comment Brewfile is a no-op; don't spend a brew invocation on it.
    if ! grep -qE '^\s*(brew|cask|tap|mas)\s' "$f"; then
      skip "$(basename "$f") has no entries"
      continue
    fi
    info "brew bundle --file=$(basename "$f")"
    if ! brew bundle --file="$f" --no-lock; then
      warn "brew bundle failed for $(basename "$f") — continuing"
    fi
  done
}
