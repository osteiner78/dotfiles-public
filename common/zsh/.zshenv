# . "$HOME/.cargo/env"

path+=${HOME}/.local/bin
# For borgmatic
# path+=('/root/.local/bin/')

EDITOR=$(command -v nvim 2>/dev/null || command -v vim)
SUDO_EDITOR=$EDITOR

# ==================== PERL LOCALE ==========================
LC_CTYPE=en_US.UTF-8
LC_ALL=en_US.UTF-8
