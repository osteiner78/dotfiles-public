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

# ------------------------------------------------------------
# Install applications
# Update Homebrew recipes
brew update
# CLI programs
brew install htop
brew install bat 
brew install curl 
brew install espanso
brew install exa 
brew install git 
brew install git-delta
brew install mackup # check https://www.bam.tech/article/setting-new-mac-for-developers-simplifying-configuration-with-dotfiles-and-macos-preferences#:~:text=There%20is%20a%20way%20to,hosted%20with%20%E2%9D%A4%20by%20GitHub
brew install mc 
brew install powerlevel10k 
brew install stow
brew install tmux 
brew install tree 
brew install wget 
brew install zsh-autosuggestions 
brew install zsh-syntax-highlighting 

# GUI apps
brew install --cask 1password 1password-cli alfred appcleaner arc dash google-chrome grandperspective itau iterm2 karabiner-elements keyboard-maestro logitech-options
brew install --cask meld mimestream nordvpn obsidian rectangle fujitsu-scansnap-home spotify steam thunderbird visual-studio-code whatsapp zoom
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
