# ~/.zshrc — shared across macOS and Linux.
#
# Load order:
#   1. this file (shared)
#   2. ~/.zshrc.os     -> symlink to .zshrc.darwin or .zshrc.linux
#   3. ~/.zshrc.local  -> untracked, per-machine (secrets, host-specific PATH)

# ---------------------------------------------------------------------------
# Homebrew — must come first so ${commands[...]} lookups below can see brew's
# binaries. The OS fragment defines the prefix; on Linux brew may be absent.
# ---------------------------------------------------------------------------
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew \
             /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  if [[ -x "$_brew" ]]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew

# clone antidote if necessary
[[ -e ~/.antidote ]] || git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote

(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv hook zsh)"

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

export LSCOLORS="exfxcxdxbxegedabagacad"
export CLICOLOR=true

# Rust toolchain, if present
[[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"
# Personal scripts
[[ -d "$HOME/.bin" ]] && export PATH="$HOME/.bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

autoload -Uz compinit && compinit

# ---------------------------------------------------------------------------
# Plugins (antidote) — reads ~/.zsh_plugins.txt
# ---------------------------------------------------------------------------
. ~/.antidote/antidote.zsh
antidote load

if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
elif (( ${+commands[fzf]} )); then
  # fzf >= 0.48 ships its own shell integration
  source <(fzf --zsh) 2>/dev/null
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
setopt NO_BG_NICE            # don't nice background tasks
setopt NO_HUP
setopt NO_LIST_BEEP
setopt LOCAL_OPTIONS         # allow functions to have local options
setopt LOCAL_TRAPS           # allow functions to have local traps
setopt HIST_VERIFY
setopt SHARE_HISTORY         # share history between sessions
setopt EXTENDED_HISTORY      # add timestamps to history
setopt PROMPT_SUBST
setopt CORRECT
setopt COMPLETE_IN_WORD
setopt IGNORE_EOF
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS  # don't record dupes in history
setopt HIST_REDUCE_BLANKS
# don't expand aliases _before_ completion has finished, like: git comm-[tab]
setopt complete_aliases

# ---------------------------------------------------------------------------
# Keybindings
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
export EDITOR='nvim'
export MANPAGER='nvim +Man!'
export BAT_THEME='Catppuccin Frappe'
export NODE_REPL_HISTORY_FILE=~/.node_repl
export NODE_OPTIONS=--max_old_space_size=8192

# volta, if installed
if [[ -d "$HOME/.volta" ]]; then
  export VOLTA_HOME="$HOME/.volta"
  export VOLTA_FEATURE_PNPM=1
  export PATH="$VOLTA_HOME/bin:$PATH"
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias reload!='. ~/.zshrc'
alias zshconfig="nvim ~/.zshrc"
alias vim=nvim
alias vimconfig="nvim ~/.config/nvim/init.lua"

alias pr="gh pr create --fill-first && gh pr view --web"
alias prd="git push && gh pr create --fill-first --draft && gh pr view --web"

# git
alias gl='git pull --prune'
alias glog="git log --graph --pretty=format:'%Cred%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"
# Remove `+` and `-` from start of diff lines; just rely upon color.
alias gd='git diff --color | sed "s/^\([^-+ ]*\)[-+ ]/\\1/" | less -r'
alias gc='git commit'
alias gco='git checkout'
alias gcb='git copy-branch-name'
alias gb='git branch'
alias gap='git add -p'
alias gp="git pull"
alias gl="git lg"

alias yarnconflict="git checkout origin/master -- yarn.lock && yarn"

# fzf search local branches
fbr() {
  local branches branch
  branches=$(git branch --all | grep -v HEAD) &&
  branch=$(echo "$branches" |
  fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //")
}

# Delete local branches whose remote is gone.
gprune() {
  local main_branch
  main_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  main_branch=${main_branch:-main}
  git checkout "$main_branch" || return 1
  git fetch --prune
  git branch -vv | awk '/: gone]/ {print $1}' | xargs -r git branch -D
}

export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"

# ---------------------------------------------------------------------------
# Optional tools
# ---------------------------------------------------------------------------
(( ${+commands[scmpuff]} )) && eval "$(scmpuff init -s)"
(( ${+commands[thefuck]} )) && eval "$(thefuck --alias)"
(( ${+commands[zoxide]} )) && eval "$(zoxide init zsh)"

# ---------------------------------------------------------------------------
# OS-specific, then machine-specific. Both are the last word.
# ---------------------------------------------------------------------------
[[ -f ~/.zshrc.os ]] && source ~/.zshrc.os
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
