# Enable Powerlevel10k instant prompt. Should stay crlose to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# For macOS
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
# For Linux 
# source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ==================== HISTORY SETUP =============================
HISTFILE=$HOME/.zhistory
SAVEHIST=3000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

# ==================== EDITOR =============================
# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi
export VISUAL="$EDITOR"

# ==================== LOAD SHELL PLUGINS (WITHOUT PLUGIN MANAGER)=======================
# For Mac
# source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# For Linux
# source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# ===================== ALIASES =========================
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
alias ll="eza -lah --color=always --long --icons=always"

alias vim="nvim"
alias c="clear"

# To run obsidian in hidpi in wayland
alias obsidian="OBSIDIAN_USE_WAYLAND=1 ~/AppImages/gearlever_obsidian_7947f7.appimage --no-sandbox -enable-features=UseOzonePlatform -ozone-platform=wayland %U"

# Tmux
alias ta="tmux new-session -A -s ${USER} >/dev/null 2>&1"
alias td="tmux detach"

# Git
alias gs="git status"
alias gcm="git commit -m " ""
alias gd="git diff"

# ==================== TMUX =================================================
# START TMUX IN EVERY SHELL LOGIN
# [[ $TERM != "screen" ]] && exec tmux

# from https://wiki.archlinux.org/title/Tmux#Start_tmux_on_every_shell_login
# if [ -x "$(command -v tmux)" ] && [ -z "${TMUX}" ]; then
#     exec tmux new-session -A -s ${USER} >/dev/null 2>&1
# fi

# ==================== FZF =================================================
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

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

# GRUVBOX THEME
_gen_fzf_default_opts() {

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

# ===================== CONDA ================================================
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/home/oliversteiner/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/home/oliversteiner/miniconda3/etc/profile.d/conda.sh" ]; then
#         . "/home/oliversteiner/miniconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/home/oliversteiner/miniconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# <<< conda initialize <<<
