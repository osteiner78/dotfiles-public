#!/bin/bash


# Set zsh as the default shell
#==============
sudo chsh -s /bin/zsh

sudo dnf update

# Git
sudo dnf install git

# Install other packages
sudo dnf install bat curl htop mc tree wget exa meld espanso solaar git-delta


# -------------------------------------------------------
# LunarVim
# Install dependencies
sudo dnf install make pip python npm node cargo ripgrep lazygit 
# Install Lvim
LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)



# -------------------------------------------------------
# Insall MesloLGS Nerd fonts
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

