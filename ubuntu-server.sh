#!/bin/bash

echo "Setting up Ubuntu Server"

# Check for Oh My Zsh and install if we don't have it
# if test ! $(which omz); then
#     /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
# fi

# Set zsh as the default shell
#==============
sudo apt update

# Install zsh and plugins
echo "Install zsh and plugins"
sudo apt install zsh zsh-autosuggestions zsh-syntax-highlighting -y

# Install powerlevel10k
echo "Installing powerlevel10k"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

# Install fzf
echo "Installing fzf"
sudo apt install fd-find
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

echo "Installing other tools"
sudo apt install eza stow bat neovim tmux zoxide -y

# Install dotfiles
echo "Installing dotfiles"
rm ~/.fzf.*
rm ~/.zshrc
cd ~/dotfiles/
stow cross-zsh
stow cross-tmux
stow cross-nvim

# Change shell to zsh
sudo passwd
sudoedit /etc/pam.d/chsh
chsh -s /bin/zsh


