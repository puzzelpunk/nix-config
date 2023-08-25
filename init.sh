#!/usr/bin/env bash
DIR=`cd $(dirname "${BASH_SOURCE[0]}") && pwd`
TIMESTAMP=`date | tr -s " " "-"`
CONF="$DIR/flake.nix"
DARWIN_TARGET_DIR="$HOME/.config/nix-darwin"
NIXOS_TARGET_DIR="/etc/nixos/"

if [[ ! -n "$1" ]];
then
  echo "Hostname argument missing. Please use the name of a sub-directory under the 'hosts' folder."
  exit 1
fi
  

if [[ ! -e "$CONF" ]];
then
  echo "'flake.nix' does not exists in $CONF"
  exit 1
fi

if [[ `uname` == "Darwin" ]];
then
  sudo scutil --set HostName $1
  echo -e "Move $DIR to $DARWIN_TARGET_DIR"
  echo ""
  echo "Then you can run:"
  echo "nix --extra-experimental-features \"nix-command flakes\" run nix-darwin -- switch --flake ~/.config/nix-darwin"
  echo ""
  echo "And then:"
  echo "darwin-rebuild switch --flake ~/.config/nix-darwin"
fi

if [[ `uname` == "Linux" ]];
then
  sudo hostname $1
  [[ -e $NIXOS_TARGET_DIR/flake.nix ]] && sudo mv /etc/nixos/flake.nix /etc/nixos/flake_$TIMESTAMP.nix
  sudo ln -sf $CONF /etc/nixos/flake.nix
  echo -e "Config initialized at $NIXOS_TARGET_DIR/flake.nix"
  echo ""
  echo "Now you can run:"
  echo "nixos-rebuild switch"
fi