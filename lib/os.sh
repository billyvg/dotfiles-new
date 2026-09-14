#!/usr/bin/env bash
# Shared helpers: OS detection, logging, symlinking.
# Sourced by install.sh — not meant to be run directly.

set -euo pipefail

# --- logging ---------------------------------------------------------------
if [[ -t 1 ]]; then
  _c_blue=$'\033[34m'; _c_green=$'\033[32m'; _c_yellow=$'\033[33m'
  _c_red=$'\033[31m';  _c_dim=$'\033[2m';    _c_off=$'\033[0m'
else
  _c_blue=; _c_green=; _c_yellow=; _c_red=; _c_dim=; _c_off=
fi

info()  { printf '%s==>%s %s\n'  "$_c_blue"   "$_c_off" "$*"; }
ok()    { printf '%s  ok%s %s\n' "$_c_green"  "$_c_off" "$*"; }
warn()  { printf '%swarn%s %s\n' "$_c_yellow" "$_c_off" "$*" >&2; }
die()   { printf '%sfail%s %s\n' "$_c_red"    "$_c_off" "$*" >&2; exit 1; }
skip()  { printf '%s    %s%s\n'  "$_c_dim"    "$*"      "$_c_off"; }

# --- OS detection ----------------------------------------------------------
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux"  ;;
    *)      die "unsupported OS: $(uname -s)" ;;
  esac
}

OS="$(detect_os)"
export OS

is_darwin() { [[ "$OS" == "darwin" ]]; }
is_linux()  { [[ "$OS" == "linux"  ]]; }

# True inside a Coder workspace.
is_coder() { [[ -n "${CODER_WORKSPACE_NAME:-}" || -n "${CODER_AGENT_URL:-}" ]]; }

has() { command -v "$1" >/dev/null 2>&1; }

# Run a command with sudo if we aren't root. Returns non-zero (rather than
# hanging on a password prompt) when sudo isn't usable.
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if has sudo && sudo -n true 2>/dev/null; then
    SUDO="sudo"
  elif has sudo; then
    SUDO="sudo"   # may prompt; acceptable interactively
  fi
fi
export SUDO

can_sudo() { [[ "$(id -u)" -eq 0 ]] || { has sudo && sudo -n true 2>/dev/null; }; }

# --- symlinking ------------------------------------------------------------
# link <source> <destination>
#
# Idempotent. If destination is already the right symlink, does nothing. If it
# is a real file or a symlink pointing elsewhere, it is moved aside to
# <destination>.bak before linking (matching Coder's own dotfiles behaviour).
link() {
  local src="$1" dst="$2"

  [[ -e "$src" ]] || { warn "missing source, skipping: $src"; return 0; }

  mkdir -p "$(dirname "$dst")"

  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink "$dst")"
    if [[ "$current" == "$src" ]]; then
      skip "$(shorten "$dst") already linked"
      return 0
    fi
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    local backup="$dst.bak"
    # Don't clobber an existing backup; stamp it instead.
    [[ -e "$backup" ]] && backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup"
    warn "backed up $(shorten "$dst") -> $(shorten "$backup")"
  fi

  ln -s "$src" "$dst"
  ok "$(shorten "$dst")"
}

# Pretty-print a path relative to $HOME.
# The replacement goes through a variable — an inline `\~` would emit the
# backslash literally, and a bare `~` risks tilde expansion.
shorten() { local tilde="~"; printf '%s' "${1/#$HOME/$tilde}"; }
