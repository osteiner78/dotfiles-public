# ==================== AUTOSTART TMUX WHEN SSH ==========================
# https://stackoverflow.com/questions/27613209/how-to-automatically-start-tmux-on-ssh-session
# See https://stackoverflow.com/questions/25207909/tmux-open-terminal-failed-not-a-terminal
if [[ $- =~ i ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
# if [ -z "$TMUX" ]; then
  exec tmux new-session -A -s osteiner
fi 

# ============================== POWERLEVEL 10K =================================
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================== ZSHRC DEFAULTS =================================
# # Set up the prompt
# autoload -Uz promptinit
# promptinit
# prompt adam1

setopt histignorealldups sharehistory

# # Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=5000
SAVEHIST=5000
HISTFILE=~/.zsh_history
#
# # Use modern completion system
autoload -Uz compinit
compinit
#
# zstyle ':completion:*' auto-description 'specify: %d'
# zstyle ':completion:*' completer _expand _complete _correct _approximate
# zstyle ':completion:*' format 'Completing %d'
# zstyle ':completion:*' group-name ''
# zstyle ':completion:*' menu select=2
# eval "$(dircolors -b)"
# zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
# zstyle ':completion:*' list-colors ''
# zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
# zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
# zstyle ':completion:*' menu select=long
# zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
# zstyle ':completion:*' use-compctl false
# zstyle ':completion:*' verbose true
#
# zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
# zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# =================================== OTHER ====================================================
bindkey "^[[A" history-search-backward
bindkey "OA" history-search-backward
bindkey "^[[B" history-search-forward
bindkey "OB" history-search-forward
# bindkey "<Down>" history-beginning-search-forward

# Moved to .zshenv
# EDITOR=/usr/local/bin/nvim
# SUDO_EDITOR=/usr/local/bin/nvim

# =================================== ALIASES ====================================================
alias ".."="cd .." 
alias "..."="cd ../.." 
alias "...."="cd ../../.." 
alias "....."="cd ../../../.." 

# alias -g ..='..'
# alias -g ...='../..'
# alias -g ....='../../..'
# alias -g .....='../../../..'
# alias -g ......='../../../../..'
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

# alias ll="ls -lah"
# alias ls="eza -a --color=always --long --icons=always --no-user"
alias ll="eza -lah --group --color=always --long --icons=always"

alias vim="nvim"
alias c="clear"

# To run obsidian in hidpi in wayland
# alias obsidian="OBSIDIAN_USE_WAYLAND=1 ~/AppImages/gearlever_obsidian_7947f7.appimage --no-sandbox -enable-features=UseOzonePlatform -ozone-platform=wayland %U"
alias code='code --enable-features=UseOzonePlatform --ozone-platform=wayland'

# Tmux
alias ta="tmux new-session -A -s ${USER} >/dev/null 2>&1"
alias td="tmux detach"

# Git
alias gs="git status"
alias gcm="git commit -m " ""
alias gd="git diff"

# Wireguard
alias wd="sudo systemctl stop wg-quick@wg0"
alias wu="sudo systemctl start wg-quick@wg0"

# ==================== YAZI =================================================
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# ==================== NNN =================================================
# alias n="nnn -dHieo -Pp"
# alias n="nnn -dDHioU -Pp"

# export NNN_BMS="c:$HOME/.config/;n:/media/nvme/;D:$HOME/Downloads/"
# export NNN_COLORS='2314'
# export NNN_PLUG="p:preview-tui;c:fzcd;a:autojump"
# # export NNN_TERMINAL='alacritty --title preview-tui'
# export NNN_USE_EDITOR=1
# export NNN_RESTRICT_NAV_OPEN=1
#
# # For live preview plugin
# export NNN_FIFO=/tmp/nnn.fifo

# ==================== FZF =================================================
# Set up fzf key bindings and fuzzy completion
# source <(fzf --zsh)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Lines below from josean-dev: https://www.josean.com/posts/7-amazing-cli-tools
# -- Use fd instead of fzf --
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# --- setup fzf theme ---
# fg="#CBE0F0"
# bg="#011628"
# bg_highlight="#143652"
# purple="#B388FF"
# blue="#06BCE4"
# cyan="#2CF9ED"

# export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"
_gen_fzf_default_opts() {

# echo "Loaded fzf"
# FZF GRUVBOX THEME 
local color00='#32302f'
local color01='#3c3836'
local color02='#504945'
local color03='#665c54'
local color04='#bdae93'
local color05='#d5c4a1'
local color06='#ebdbb2'
local color07='#fbf1c7'
local color08='#fb4934'
local color09='#fe8019'
local color0A='#fabd2f'
local color0B='#b8bb26'
local color0C='#8ec07c'
local color0D='#83a598'
local color0E='#d3869b'
local color0F='#d65d0e'

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS"\
" --color=bg+:$color01,bg:$color00,spinner:$color0C,hl:$color0D"\
" --color=fg:$color04,header:$color0D,info:$color0A,pointer:$color0C"\
" --color=marker:$color0C,fg+:$color06,prompt:$color0A,hl+:$color0D"
}

_gen_fzf_default_opts

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# ============== BAT THEME ==================
export BAT_THEME=gruvbox-dark

# ============ Zoxide (better cd) =========================
eval "$(zoxide init zsh)"

alias cd="z"

# ==================== PERL LOCALE ==========================
# LC_CTYPE=en_US.UTF-8
# LC_ALL=en_US.UTF-8

# ==================== POWERLEVEL 10K ==========================
# Load powerlevel10k theme - Cross-platform
if [ "$(uname -s)" = "Darwin" ]; then
    source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
elif [ "$(uname -s)" =  "Linux" ]; then
    # source /usr/share/powerlevel10k/powerlevel10k.zsh-theme
	source ~/powerlevel10k/powerlevel10k.zsh-theme
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ==================== ZSH PLUGINS  ==========================
# Load shell plugins - Cross-platform
if [ "$(uname -s)" = "Darwin" ]; then
    source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ "$(uname -s)" =  "Linux" ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# ==================== ADD CUSTOM SCRIPTS TO PATH ==========================
# path+=${HOME}/.local/bin

# For borgmatic
# path+=('/root/.local/bin/')
path+=('/opt/nvim')

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/oliversteiner/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/oliversteiner/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/oliversteiner/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/oliversteiner/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
