#!/usr/bin/env sh
version=`nixos-version | cut -d"." -f 1,2`

nix-channel --add https://github.com/nix-community/home-manager/archive/release-${version}.tar.gz home-manager
nix-channel --update