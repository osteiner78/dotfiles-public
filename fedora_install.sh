#!/bin/bash

echo "Setting up your PC..."

# Check for Oh My Zsh and install if we don't have it
if test ! $(which omz); then
    /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi

# Set zsh as the default shell
#==============
sudo chsh -s /bin/zsh


# Install packages
sudo dnf update

sudo dnf install bat
sudo dnf install curl
sudo dnf install espanso
sudo dnf install exa
sudo dnf install git
sudo dnf install git-delta
sudo dnf install htop
sudo dnf install mc
sudo dnf install meld
sudo dnf install powerlevel110k
sudo dnf install stow
sudo dnf install tmux
sudo dnf install solaar
sudo dnf install tree
sudo dnf install wget
sduo dnf install zsh-autosuggestions 
sudo dnf install zsh-syntax-highlighting


# -------------------------------------------------------
# LunarVim
# Install dependencies
sudo dnf install make pip python npm node cargo ripgrep lazygit 
# Install Lvim
LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)

# -------------------------------------------------------
# Install MesloLGS Nerd fonts
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
curl -L --create-dirs --output-dir ".local/share/fonts" -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20BoldItalic.ttf

# -------------------------------------------------------
# Alacritty
# Install dependencies
sudo dnf install cmake freetype-devel fontconfig-devel libxcb-devel libxkbcommon-devel g++

# build binary at target/release/alacritty
cargo build --release --no-default-features --features=wayland
# -------------------------------------------------------

