# ==================== AUTOSTART TMUX WHEN SSH =========================
# Auto-attach/create tmux for interactive SSH sessions.
if [[ $- =~ i ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
  tmux attach-session -t osteiner || tmux new-session -s osteiner
  exit
  # exec tmux new-session -A -s osteiner
fi


# ============================== ZSHRC DEFAULTS =================================
# (Legacy promptinit kept to preserve your original behavior)
# autoload -Uz promptinit
# promptinit
# prompt adam1

# Deduplicate PATH entries
typeset -U path PATH

# History & completion behavior
setopt HISTIGNOREALLDUPS SHAREHISTORY
setopt HIST_IGNORE_SPACE EXTENDED_HISTORY HIST_VERIFY
setopt AUTO_PUSHD PUSHD_SILENT PUSHD_IGNORE_DUPS

# Keybindings style
bindkey -e

# History file and size
HISTSIZE=20000
SAVEHIST=20000
HISTFILE=~/.zsh_history

# --- Global Zsh Completion Styles ---
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' menu select=long
zstyle ':completion:*' verbose true
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'

# Formatting for headers and descriptions
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:messages' format ' %d'
zstyle ':completion:*:warnings' format ' [%d: no matches found]'
zstyle ':completion:*' auto-description 'specify: %d'

# Colors and Prompts
command -v dircolors >/dev/null 2>&1 && eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=01;31'
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

alias ll="eza -lah --group --color=always --icons=always"
alias vim="nvim"
alias c="clear"

# Fzf finders
# Find files in subfolders
# alias ff='fd . --type f --hidden --follow --exclude .git | fzf --ansi'

# Wayland Code
# alias code='code --enable-features=UseOzonePlatform --ozone-platform=wayland'

# Tmux helpers
alias ta="tmux new-session -A -s ${USER} >/dev/null"
alias td="tmux detach"

# Git QoL
alias gs="git status"
alias gcm='git commit -m'
alias gd="git diff"

# Wireguard
alias wd="sudo systemctl stop wg-quick@wg0"
alias wu="sudo systemctl start wg-quick@wg0"

# Find files in subfolders
ff() {
  local fd_command="fd --type f --hidden --follow --exclude .git --exclude .history --exclude node_modules --exclude target --exclude .cache --color=always"
  local file_path
  
  # 1. Capture the selected file path
  file_path=$(fzf --ansi --disabled --query "$*" \
    --bind "start:reload($fd_command . || true)" \
    --bind "change:reload($fd_command {q} || true)" \
    --preview 'bat --color=always --style=numbers {}' \
    --header "ENTER to cd to this file's directory" \
    --layout=reverse --height=90% --border)

  # 2. If a file was selected, cd to its parent directory
  if [[ -n "$file_path" ]]; then
    # dirname extracts the path up to the last slash
    cd "$(dirname "$file_path")" || return
    
    # Optional: list files in the new directory so you see where you are
    eza --color=always
  fi
}

# Find string in subfolders and open in Neovim
fs() {
  local rg_command="rg --column --line-number --no-heading --color=always --smart-case"
  
  fzf --ansi --disabled --query "$*" \
    --bind "start:reload($rg_command -- . || true)" \
    --bind "change:reload($rg_command -- {q} || true)" \
    --delimiter : \
    --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
    --bind 'enter:become(nvim {1} +{2})'
}

# ==================== ENVIRONMENT =================================================
# Tell systemctl not to use a pager
export SYSTEMD_PAGER=cat
export SYSTEMD_LESS=

# ==================== YAZI =================================================
# Removed WAYLAND_DISPLAY and XDG_SESSION_TYPE to force to use chafa for previews
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  env -u WAYLAND_DISPLAY -u DISPLAY XDG_SESSION_TYPE=tty \
    yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ==================== FZF =================================================
# (Order preserved exactly)
export FZF_DEFAULT_COMMAND='fd --hidden --follow --strip-cwd-prefix --exclude .git --exclude .history --exclude node_modules --exclude target --exclude .cache'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --strip-cwd-prefix --exclude .git --exclude .history --exclude node_modules --exclude target --exclude .cache'

_fzf_compgen_path() { fd --hidden --follow --exclude .git --exclude .history --exclude node_modules --exclude target --exclude .cache . "$1" }
_fzf_compgen_dir()  { fd --type=d --hidden --follow --exclude .git --exclude .history --exclude node_modules --exclude target --exclude .cache . "$1" }

_gen_fzf_default_opts() {
  # Gruvbox palette
  local color00='#32302f' color01='#3c3836' color02='#504945' color03='#665c54'
  local color04='#bdae93' color05='#d5c4a1' color06='#ebdbb2' color07='#fbf1c7'
  local color08='#fb4934' color09='#fe8019' color0A='#fabd2f' color0B='#b8bb26'
  local color0C='#8ec07c' color0D='#83a598' color0E='#d3869b' color0F='#d65d0e'

  local opts="$FZF_DEFAULT_OPTS \
--color=bg+:${color01},bg:${color00},spinner:${color0C},hl:${color0D} \
--color=fg:${color04},header:${color0D},info:${color0A},pointer:${color0C} \
--color=marker:${color0C},fg+:${color06},prompt:${color0A},hl+:${color0D}"

  export FZF_DEFAULT_OPTS="$opts"
}
_gen_fzf_default_opts

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_CTRL_T_OPTS="--preview='$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview='eza --tree --color=always {} | head -200'"

# ============== FZF-TAB =================

fzf_tab_plugin="$HOME/.zsh/fzf-tab/fzf-tab.zsh"

# fpath must be updated before compinit so fzf-tab completion functions are registered
[[ -r "$fzf_tab_plugin" ]] && fpath=(~/.zsh/fzf-tab $fpath)

# ----- Standard zsh completion system -----
autoload -Uz compinit
compinit

# If fzf-tab is present -> configure everything
if [[ -r "$fzf_tab_plugin" ]]; then
    if [[ -n $TMUX ]] && (( $+commands[fzf-tmux] )); then
      zstyle ':fzf-tab:*' fzf-command 'fzf-tmux -p 80%,70%'
    else
      zstyle ':fzf-tab:*' fzf-command fzf
    fi

    zstyle ':fzf-tab:*' fzf-preview 'if [[ -d $realpath ]]; then eza --tree --color=always $realpath | head -200; else bat --style=numbers --color=always $realpath; fi'
    zstyle ':completion:*:git-checkout:*' sort false
    zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
    zstyle ':completion:*' menu no
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
    zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    zstyle ':fzf-tab:*' switch-group '<' '>'
    zstyle ':fzf-tab:*' show-help yes
    zstyle ':fzf-tab:*' group-tidy true
    zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --color=always $realpath'

    # Load fzf-tab plugin
    source "$fzf_tab_plugin"

    # Make sure fzf-tab owns TAB (after everything else)
    if (( ${+functions[fzf-tab-complete]} )); then
        bindkey -M emacs '^I' fzf-tab-complete
        bindkey -M viins '^I' fzf-tab-complete
    fi
fi

# Load fzf keybindings (Ctrl-R / Ctrl-T / Alt-C etc.)
# Keep this after fzf-tab — your working order.
command -v fzf >/dev/null && source <(fzf --zsh)

# ============== BAT THEME ==================
export BAT_THEME=gruvbox-dark

# ============ Zoxide (better cd) =========================
if command -v zoxide >/dev/null; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

# ==================== PERL LOCALE ==========================
# (left commented intentionally)
# LC_CTYPE=en_US.UTF-8
# LC_ALL=en_US.UTF-8

# ==================== ZSH PLUGINS  ==========================
# (Kept at the very end — your original order)
if [[ "$(uname -s)" == "Darwin" ]]; then
  local brew_prefix="$(brew --prefix)"
  [[ -r "$brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] \
    && source "$brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [[ -r "$brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] \
    && source "$brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [[ "$(uname -s)" == "Linux" ]]; then
  [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
    && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
    && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Locations for Arch Linux
  [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
    && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
    && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ==================== ADD CUSTOM SCRIPTS TO PATH ==========================
# (Kept as-is; order preserved)
path+=${HOME}/.local/bin
# path+=('/root/.local/bin/')
path+=('/opt/nvim')

# >>> conda initialize >>>
if [[ "$(uname -s)" == "Darwin" ]]; then
  if __conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"; then
    eval "$__conda_setup"
  elif [[ -r "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
  else
    export PATH="$HOME/miniconda3/bin:$PATH"
  fi
  unset __conda_setup
elif [[ "$(uname -s)" == "Linux" ]]; then
  for _conda_prefix in "$HOME/miniconda3" "$HOME/anaconda3" "/opt/miniconda3" "/opt/anaconda3"; do
    if [[ -x "$_conda_prefix/bin/conda" ]]; then
      if __conda_setup="$("$_conda_prefix/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"; then
        eval "$__conda_setup"
      elif [[ -r "$_conda_prefix/etc/profile.d/conda.sh" ]]; then
        . "$_conda_prefix/etc/profile.d/conda.sh"
      else
        export PATH="$_conda_prefix/bin:$PATH"
      fi
      unset __conda_setup
      break
    fi
  done
  unset _conda_prefix
fi
# <<< conda initialize <<<

# NVM (lazy-loaded for faster shell startup)
export NVM_DIR="$HOME/.nvm"
_nvm_lazy_load() {
  unfunction nvm node npm npx 2>/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]]          && source "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
}
nvm()  { _nvm_lazy_load; nvm  "$@" }
node() { _nvm_lazy_load; node "$@" }
npm()  { _nvm_lazy_load; npm  "$@" }
npx()  { _nvm_lazy_load; npx  "$@" }

# (( ! ${+functions[p10k]} )) || p10k finalize
command -v oh-my-posh >/dev/null && eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/config.toml)"

# Added by Antigravity
export PATH="/Users/oliversteiner/.antigravity/antigravity/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="$PATH:$HOME/.npm-global/bin"


# Gemini API Key
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
