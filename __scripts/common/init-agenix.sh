#!/usr/bin/env sh

sudo nix-channel --add https://github.com/ryantm/agenix/archive/main.tar.gz agenix
sudo nix-channel --update