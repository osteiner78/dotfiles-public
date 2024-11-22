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
echo "\n================= Installing other tools ======================"
sudo apt install eza stow btop neovim tmux tree zoxide unzip -y

echo "\n ================== Install zsh and plugins ======================"
sudo apt install zsh zsh-autosuggestions zsh-syntax-highlighting -y

# Install powerlevel10k
echo "\n==================== Installing powerlevel10k ========================="
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

# Install fzf
echo "\n ======================= Installing fzf ============================"
sudo apt install fd-find
mkdir ~/.local/bin
ln -s $(which fdfind) ~/.local/bin/fd

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

# Install yazi
echo "\n========================== Installing yazi ==========================="
cd ~
wget https://github.com/sxyazi/yazi/releases/download/v0.3.3/yazi-x86_64-unknown-linux-gnu.zip
unzip yazi-x86_64-unknown-linux-gnu.zip
mv ~/yazi-x86_64-unknown-linux-gnu/yazi ~/.local/bin

# Install bat
echo "\n ============================ Installing bat ==========================="
sudo apt install bat -y
mkdir -p ~/.local/bin
ln -s /usr/bin/batcat ~/.local/bin/bat

# Install dotfiles
echo "\n============================ Installing dotfiles ============================"
rm ~/.fzf.*
rm ~/.zshrc
cd ~/dotfiles/
stow cross-zsh
stow cross-tmux
stow cross-nvim
stow cross-yazi
stow cross-git

# Remove heavy neovim plugins
rm ~/.config/nvim/lua/plugins/telescope.lua
rm ~/.config/nvim/lua/plugins/treesitter.lua
rm ~/.config/nvim/lua/plugins/neo-tree.lua
rm ~/.config/nvim/lua/plugins/lspconfig.lua
rm ~/.config/nvim/lua/plugins/todo-comments.lua
rm ~/.config/nvim/lua/plugins/conform.lua
rm ~/.config/nvim/lua/plugins/trouble.lua
rm ~/.config/nvim/lua/plugins/dashboard-nvim.lua

# Change shell to zsh
sudo passwd
sudoedit /etc/pam.d/chsh
chsh -s /bin/zsh


