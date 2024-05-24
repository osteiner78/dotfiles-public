#!/bin/bash
# Inspired by https://github.com/Remi-deronzier/public-dotfiles/blob/main/install.sh

echo "Setting up your Mac..."

# Check for Oh My Zsh and install if we don't have it
if test ! $(which omz); then
    /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi

# Check for Homebrew and install if we don't have it
if test ! $(which brew); then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ============= INSTALL APPLICATIONS ================

# Update Homebrew recipes
brew update

# CLI programs
brew install bat curl eza fzf htop mc neovim stow tmux tree wget

# Git related
brew install git git-delta lazygit

# Karabiner Elements
brew install --cask karabiner-elements
brew install goku

# Text replacement
brew tap espanso/espanso # From https://espanso.org/docs/install/mac/
brew install espanso


# Ice - Bartender replacement - https://github.com/jordanbaird/Ice
brew install jordanbaird-ice

brew install mackup # check https://www.bam.tech/article/setting-new-mac-for-developers-simplifying-configuration-with-dotfiles-and-macos-preferences#:~:text=There%20is%20a%20way%20to,hosted%20with%20%E2%9D%A4%20by%20GitHub

# Maccy - Clipboard manager - https://github.com/p0deje/Maccy?tab=readme-ov-file#install
brew install maccy

# Window management
brew install --cask rectangle
brew install yabai spaceman

# Simulate middle click with trackpad - https://github.com/artginzburg/MiddleClick-Sonoma#install
brew install --cask --no-quarantine middleclick # Simulate triple click with trackpad

# macOS dark mode toggle
brew install dark-mode

# GUI APPS
# Utils
brew install --cask 1password 1password-cli alfred appcleaner grandperspective
brew install --cask itau
brew install --cask logi-options-plus
brew install --cask nordvpn
brew install --cask obsidian
brew install --cask fujitsu-scansnap-home
brew install --cask spotify
brew install --cask betterdisplay # https://github.com/waydabber/BetterDisplay
brew install --cask soulver
brew install --cask cheatsheet

# Trading
brew install --cask ibkr tradingview

# Browsers
brew install --cask arc google-chrome

# Coding
brew install --cask visual-studio-code dash iterm2 meld
brew install --cask sublime-text

# Comms
brew install --cask mimestream thunderbird whatsapp

# Gaming
brew install --cask steam whisky

# ARCHIVE
# brew install powerlevel10k 
# brew install zsh-autosuggestions 
# brew install zsh-syntax-highlighting 
# brew install --cask zoom
# brew install --cask keyboard-maestro
# brew install --cask logitech-options

# ------------------------------------------------------------
# Instal Nerd fonts
brew tap homebrew /cask-fonts
brew install font-meslo-lg-nerd
# ------------------------------------------------------------

# Define a function which rename a `target` file to `target.backup` if the file
# exists and if it's a 'real' file, ie not a symlink
backup() {
    target=$1
    if [ -e "$target" ]; then
        if [ ! -L "$target" ]; then
            mv "$target" "$target.backup"
            echo "-----> Moved your old $target config file to $target.backup"
        fi
    fi
}

# For all files `$name` in the present folder except `*.zsh`,
# backup the target file located at `~/.$name` and symlink `$name` to `~/.$name`
for name in espanso git karabiner mackup mc p10k skhd yabai zsh mackup.cfg; do
    if [ ! -d "$name" ]; then
        target="$HOME/.$name"
        backup $target
        stow $target
    fi
done

mackup restore

echo 'Install Menlo font from:'
echo 'https://gist.github.com/qrush/1595572#file-menlo-powerline-otf'

# Set macOS preferences - we will run this last because this will reload the shell
source ./macos

# Refresh the current terminal with the newly installed configuration
exec zsh

echo "👌 Everything done!"
