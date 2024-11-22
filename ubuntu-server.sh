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
ln -s $(which fdfind) ~/.local/bin/fd

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

# Install yazi
echo "Installing yazi"
cd ~
wget https://github.com/sxyazi/yazi/releases/download/v0.3.3/yazi-x86_64-unknown-linux-gnu.zip
unzip yazi-x86_64-unknown-linux-gnu.zip
mv ~/yazi-x86_64-unknown-linux-gnu/yazi ~/.local/bin

# Install bat
echo "Installing bat"
sudo apt install bat -y
mkdir -p ~/.local/bin
ln -s /usr/bin/batcat ~/.local/bin/bat

echo "Installing other tools"
sudo apt install eza stow btop neovim tmux tree zoxide unzip -y

# Install dotfiles
echo "Installing dotfiles"
rm ~/.fzf.*
rm ~/.zshrc
cd ~/dotfiles/
stow cross-zsh
stow cross-tmux
stow cross-nvim
stow cross-yazi
stow cross-git

# Change shell to zsh
sudo passwd
sudoedit /etc/pam.d/chsh
chsh -s /bin/zsh


