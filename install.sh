#!/bin/bash

# WORK IN PROGRESS


# Set git user
git config --global user.name "Oliver Steiner"
config --global user.email "osteiner@gmail.com"


if [ `uname` == "Darwin" ]; then
    git config --global merge.tool opendiff
    git config --global diff.tool opendiff

    echo 'Install Menlo font from:'
    echo 'https://gist.github.com/qrush/1595572#file-menlo-powerline-otf'
else
    git config --global merge.tool meld
    git config --global diff.tool meld
fi