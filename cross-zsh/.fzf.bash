# Setup fzf
# ---------
if [[ ! "$PATH" == */home/osteiner/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/osteiner/.fzf/bin"
fi

eval "$(fzf --bash)"
