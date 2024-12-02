#!/bin/bash

echo "Setting up your Ubuntu/Debian..."

# Check for Oh My Zsh and install if we don't have it
# if test ! $(which omz); then
#     /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
# fi


# Install packages
sudo apt update
sudo apt upgrade

sudo apt install bat curl eza fzf git git-delta htop btop neovim neofetch nnn stow tmux tree wget zsh-autosuggestions zsh-syntax-highlightning
# -------------------------------------------------------
# Install MesloLGS Nerd fonts
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20BoldItalic.ttf

 # Install conda
 # Create tensorflow environment from file
