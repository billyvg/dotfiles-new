# ~/.zshrc — shared across macOS and Linux.
#
# Load order:
#   1. this file (shared)
#   2. ~/.zshrc.os     -> symlink to .zshrc.darwin or .zshrc.linux
#   3. ~/.zshrc.local  -> untracked, per-machine (secrets, host-specific PATH)

# VSCode/Cursor run their own shell integration and don't need any of this.
if [[ "$TERM_PROGRAM" == "vscode" || "$TERM_PROGRAM" == "cursor" ]]; then
  return
fi

# clone antidote if necessary
[[ -e ~/.antidote ]] || git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote

# Source the output of a slow `<tool> init`-style command from a cache file.
# The cache is regenerated whenever the tool's binary is newer than the cache.
# Usage: _cached_init <name> <command> [args...]
_cached_init() {
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-init-$1.zsh"
  shift
  local bin="${commands[$1]:-$1}"
  if [[ ! -s "$cache" || ! "$cache" -nt "$bin" ]]; then
    [[ -d "${cache:h}" ]] || mkdir -p "${cache:h}"
    "$@" > "$cache"
  fi
  source "$cache"
}

# Homebrew first: it puts brew's bin on PATH and its site-functions on fpath,
# which everything below (direnv, compinit, plugins) depends on. Covers both
# macOS prefixes and both linuxbrew prefixes.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew \
             /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  if [[ -x "$_brew" ]]; then
    _cached_init brew "$_brew" shellenv
    break
  fi
done
unset _brew

[[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"
[[ -d "$HOME/.bin" ]] && export PATH="$HOME/.bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# direnv export must run before the p10k instant prompt; the hook goes after it.
(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv hook zsh)"

# ZSH
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

export LSCOLORS="exfxcxdxbxegedabagacad"
export CLICOLOR=true

# source antidote
. ~/.antidote/antidote.zsh

# generate and source plugins from ~/.zsh_plugins.txt
antidote load

# OS fragment runs here so it can add to fpath (sentry completions on macOS)
# before compinit below picks fpath up.
[[ -f ~/.zshrc.os ]] && source ~/.zshrc.os

# Completion system. Runs after antidote/brew/the OS fragment have populated
# fpath so their completions are included. -C skips the security audit and the
# "has fpath changed?" check, which are the slow parts; run `compinit` by hand
# (or delete ~/.zcompdump) after installing a tool with new completions.
autoload -Uz compinit && compinit -C
[[ ~/.zcompdump.zwc -nt ~/.zcompdump ]] || zcompile ~/.zcompdump

if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
elif (( ${+commands[fzf]} )); then
  # fzf >= 0.48 ships its own shell integration
  source <(fzf --zsh) 2>/dev/null
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

setopt NO_BG_NICE # don't nice background tasks
setopt NO_HUP
setopt NO_LIST_BEEP
setopt LOCAL_OPTIONS # allow functions to have local options
setopt LOCAL_TRAPS # allow functions to have local traps
setopt HIST_VERIFY
setopt SHARE_HISTORY # share history between sessions ???
setopt EXTENDED_HISTORY # add timestamps to history
setopt PROMPT_SUBST
setopt CORRECT
setopt COMPLETE_IN_WORD
setopt IGNORE_EOF
setopt APPEND_HISTORY # adds history
setopt INC_APPEND_HISTORY SHARE_HISTORY  # adds history incrementally and share it across sessions
setopt HIST_IGNORE_ALL_DUPS  # don't record dupes in history
setopt HIST_REDUCE_BLANKS
# don't expand aliases _before_ completion has finished
#   like: git comm-[tab]
setopt complete_aliases

bindkey '^[^[[D' backward-word
bindkey '^[^[[C' forward-word
bindkey '^[[5D' beginning-of-line
bindkey '^[[5C' end-of-line
bindkey '^[[3~' delete-char
bindkey '^?' backward-delete-char
bindkey '^u' backward-kill-line

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

autoload -U edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line


# NODE/NVM
export NODE_REPL_HISTORY_FILE=~/.node_repl

# ALIASES
# NOTE: `ls` is aliased in the OS fragment -- BSD ls wants -G, GNU wants --color.
alias reload!='. ~/.zshrc'
alias zshconfig="nvim ~/.zshrc"
alias pr="gh pr create --fill-first && gh pr view --web"
alias prd="git push && gh pr create --fill-first --draft && gh pr view --web"
alias vim=nvim
alias vimconfig="nvim ~/.config/nvim/init.lua"
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias create_wt='~/.claude/create-worktree.sh'

# The rest of my fun git aliases
alias gl='git pull --prune'
alias glog="git log --graph --pretty=format:'%Cred%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"

# Remove `+` and `-` from start of diff lines; just rely upon color.
alias gd='git diff --color | sed "s/^\([^-+ ]*\)[-+ ]/\\1/" | less -r'

alias gc='git commit'
alias gco='git checkout'
alias gcb='git copy-branch-name'
alias gb='git branch'
# alias gs='git status -sb' # upgrade your git if -sb breaks for you. it's fun.
alias gap='git add -p'
alias gp="git pull"
alias gl="git lg"
alias c="claude --dangerously-skip-permissions"
alias cs="config status"

# fzf search local branches
fbr() {
  local branches branch
  branches=$(git branch --all | grep -v HEAD) &&
  branch=$(echo "$branches" |
  fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //")
}

# VIM
export NEOVIM_JS_DEBUG=/tmp/nvim_js_debug
export EDITOR='nvim'

alias yarnconflict="git checkout origin/master -- yarn.lock && yarn"
# can use `gh poi` instead
alias gprunemerged='git checkout master && comm -12 <(git branch | sed "s/ *//g") <(git remote prune origin | sed "s/^.*origin\///g") | xargs -L1 -J % git branch -D %'
alias gpm='git checkout main && comm -12 <(git branch | sed "s/ *//g") <(git remote prune origin | sed "s/^.*origin\///g") | xargs -L1 -J % git branch -D %'

export NODE_OPTIONS=--max_old_space_size=8192
export MANPAGER='nvim +Man!'
# export BAT_THEME='Monokai Extended'
export BAT_THEME='Catppuccin Frappe'

if [[ -d "$HOME/.volta" ]]; then
  export VOLTA_HOME="$HOME/.volta"
  export VOLTA_FEATURE_PNPM=1
  export PATH="$VOLTA_HOME/bin:$PATH"
fi

[[ -f ~/.sentryrc ]] && source ~/.sentryrc

# Load plugins.
(( ${+commands[scmpuff]} )) && eval "$(scmpuff init -s)"

# thefuck: defining the alias costs ~100ms of Python startup, so only do it
# the first time `fuck` is actually run.
if (( ${+commands[thefuck]} )); then
  fuck() { unfunction fuck; eval "$(thefuck --alias)"; fuck "$@"; }
fi

(( ${+commands[zoxide]} )) && _cached_init zoxide zoxide init zsh

export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"

# Go
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# bun
if [[ -d "$HOME/.bun" ]]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  [[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by `rbenv init` on Tue 28 Oct 2025 13:35:25 EDT
(( ${+commands[rbenv]} )) && _cached_init rbenv rbenv init - --no-rehash zsh

# Machine-specific, always last.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
