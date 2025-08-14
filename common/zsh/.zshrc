# ============================== POWERLEVEL 10K =================================
# Keep instant prompt near the top to avoid flicker.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==================== AUTOSTART TMUX WHEN SSH =========================
# Auto-attach/create tmux for interactive SSH sessions.
if [[ $- =~ i ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
  exec tmux new-session -A -s osteiner
fi

# ==================== POWERLEVEL 10K ==========================
# Load p10k theme per-OS (guarded).
if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ -r /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ]] \
    && source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
elif [[ "$(uname -s)" == "Linux" ]]; then
  [[ -r ~/powerlevel10k/powerlevel10k.zsh-theme ]] \
    && source ~/powerlevel10k/powerlevel10k.zsh-theme
fi
[[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ============================== ZSHRC DEFAULTS =================================
# (Legacy promptinit kept to preserve your original behavior)
autoload -Uz promptinit
promptinit
prompt adam1

# History & completion behavior
setopt histignorealldups sharehistory
setopt completealiases

# Keybindings style
bindkey -e

# History file and size
HISTSIZE=5000
SAVEHIST=5000
HISTFILE=~/.zsh_history

# ----- Completion system (first pass; keep order) -----
autoload -Uz compinit
compinit

# Completion styles (kept as-is; grouped)
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
command -v dircolors >/dev/null 2>&1 && eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# =================================== OTHER ====================================================
# History prefix search on arrows (keep exact sequences)
bindkey "^[[A" history-search-backward
bindkey "OA"  history-search-backward
bindkey "^[[B" history-search-forward
bindkey "OB"  history-search-forward
# bindkey "<Down>" history-beginning-search-forward

# =================================== ALIASES ====================================================
alias ".."="cd .."
alias "..."="cd ../.."
alias "...."="cd ../../.."
alias "....."="cd ../../../.."
alias /="cd /"

alias -- -='cd -'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

alias ll="eza -lah --group --color=always --long --icons=always"
alias vim="nvim"
alias c="clear"

# Wayland Code
alias code='code --enable-features=UseOzonePlatform --ozone-platform=wayland'

# Tmux helpers
alias ta="tmux new-session -A -s ${USER} >/dev/null 2>&1"
alias td="tmux detach"

# Git QoL
alias gs="git status"
gcm() { git commit -m "$*"; }
alias gd="git diff"

# Wireguard
alias wd="sudo systemctl stop wg-quick@wg0"
alias wu="sudo systemctl start wg-quick@wg0"

# ==================== YAZI =================================================
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ==================== NNN =================================================
# (kept commented; unchanged)
# alias n="nnn -dHieo -Pp"
# alias n="nnn -dDHioU -Pp"
# export NNN_BMS="c:$HOME/.config/;n:/media/nvme/;D:$HOME/Downloads/"
# export NNN_COLORS='2314'
# export NNN_PLUG="p:preview-tui;c:fzcd;a:autojump"
# export NNN_USE_EDITOR=1
# export NNN_RESTRICT_NAV_OPEN=1
# export NNN_FIFO=/tmp/nnn.fifo

# ==================== FZF =================================================
# (Order preserved exactly)
export FZF_DEFAULT_COMMAND='fd --hidden --follow --strip-cwd-prefix --exclude .git --exclude .history --exclude node_modules --exclude target --exclude .cache'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --strip-cwd-prefix --exclude .git --exclude .history --exclude node_modules --exclude target --exclude .cache'

_fzf_compgen_path() { fd --hidden --follow --exclude .git . "$1" }
_fzf_compgen_dir()  { fd --type=d --hidden --follow --exclude .git . "$1" }

_gen_fzf_default_opts() {
  # Gruvbox palette
  local color00='#32302f' color01='#3c3836' color02='#504945' color03='#665c54'
  local color04='#bdae93' color05='#d5c4a1' color06='#ebdbb2' color07='#fbf1c7'
  local color08='#fb4934' color09='#fe8019' color0A='#fabd2f' color0B='#b8bb26'
  local color0C='#8ec07c' color0D='#83a598' color0E='#d3869b' color0F='#d65d0e'
  export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS"\
  " --color=bg+:$color01,bg:$color00,spinner:$color0C,hl:$color0D"\
  " --color=fg:$color04,header:$color0D,info:$color0A,pointer:$color0C"\
  " --color=marker:$color0C,fg+:$color06,prompt:$color0A,hl+:$color0D"
}
_gen_fzf_default_opts

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_CTRL_T_OPTS="--preview='$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview='eza --tree --color=always {} | head -200'"

# ============== FZF-TAB =================
# (Order preserved exactly)
fpath=(~/.zsh/plugins/fzf-tab $fpath)

if [[ -n $TMUX ]] && (( $+commands[fzf-tmux] )); then
  zstyle ':fzf-tab:*' fzf-command 'fzf-tmux -p 80%,70%'
else
  zstyle ':fzf-tab:*' fzf-command fzf
fi

zstyle ':fzf-tab:*' fzf-preview 'if [[ -d $realpath ]]; then eza --tree --color=always $realpath | head -200; else bat --style=numbers --color=always $realpath; fi'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --color=always $realpath'

# (Second compinit kept because your working setup had it here too)
autoload -U compinit
compinit

# Load fzf-tab plugin (manual install)
[[ -r ~/.zsh/plugins/fzf-tab/fzf-tab.zsh ]] && source ~/.zsh/plugins/fzf-tab/fzf-tab.zsh

# Load fzf keybindings (Ctrl-R / Ctrl-T / Alt-C etc.)
# Keep this after fzf-tab — your working order.
source <(fzf --zsh)

# Make sure fzf-tab owns TAB (after everything else)
bindkey -M emacs '^I' fzf-tab-complete
bindkey -M viins '^I' fzf-tab-complete

# ============== BAT THEME ==================
export BAT_THEME=gruvbox-dark

# ============ Zoxide (better cd) =========================
eval "$(zoxide init zsh)"
alias cd="z"

# ==================== PERL LOCALE ==========================
# (left commented intentionally)
# LC_CTYPE=en_US.UTF-8
# LC_ALL=en_US.UTF-8

# ==================== ZSH PLUGINS  ==========================
# (Kept at the very end — your original order)
if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ -r "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] \
    && source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [[ -r "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] \
    && source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [[ "$(uname -s)" == "Linux" ]]; then
  [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
    && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
    && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# ==================== ADD CUSTOM SCRIPTS TO PATH ==========================
# (Kept as-is; order preserved)
# path+=${HOME}/.local/bin
# path+=('/root/.local/bin/')
path+=('/opt/nvim')

# >>> conda initialize >>>
# (Kept verbatim but guarded)
if [[ "$(uname -s)" == "Darwin" ]]; then
  if __conda_setup="$('/Users/oliversteiner/miniconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"; then
    eval "$__conda_setup"
  elif [[ -r "/Users/oliversteiner/miniconda3/etc/profile.d/conda.sh" ]]; then
    . "/Users/oliversteiner/miniconda3/etc/profile.d/conda.sh"
  else
    export PATH="/Users/oliversteiner/miniconda3/bin:$PATH"
  fi
  unset __conda_setup
fi
# <<< conda initialize <<<

# NVM (guarded)
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"
