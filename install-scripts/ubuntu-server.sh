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
echo -e " ================== Install zsh and plugins ======================"
sudo apt install zsh zsh-autosuggestions zsh-syntax-highlighting -y

# Install powerlevel10k
echo -e "==================== Installing powerlevel10k ========================="
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k


echo -e "================= Installing other tools ======================"
sudo apt install stow btop tmux tree zoxide net-tools unzip git-diff -y

echo -e "================= Installing eza ====================="
sudo apt install gpg -y
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install eza -y

echo -e "================= Installing neovim ===================="
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:neovim-ppa/stable
sudo apt-get update
sudo apt-get install neovim -y

echo -e "======================= Installing fzf ============================"
sudo apt install fd-find
mkdir -p ~/.local/bin
ln -s $(which fdfind) ~/.local/bin/fd

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all

echo -e "========================== Installing yazi ==========================="
cd ~
wget https://github.com/sxyazi/yazi/releases/download/v0.3.3/yazi-x86_64-unknown-linux-gnu.zip
unzip yazi-x86_64-unknown-linux-gnu.zip
mv ~/yazi-x86_64-unknown-linux-gnu/yazi ~/.local/bin

echo -e "============================ Installing bat ==========================="
sudo apt install bat -y
ln -s /usr/bin/batcat ~/.local/bin/bat

# Install dotfiles
echo -e "============================ Installing dotfiles ============================"
rm ~/.fzf.*
rm ~/.zshrc
cd ~/dotfiles/
stow cross-zsh
stow cross-tmux
stow cross-nvim
stow cross-yazi
stow cross-git
stow cross-btop

# Change sudoedit editor (manual)
sudo update-alternatives --config editor

# Change shell to zsh
sudo passwd
sudoedit /etc/pam.d/chsh
chsh -s /bin/zsh
