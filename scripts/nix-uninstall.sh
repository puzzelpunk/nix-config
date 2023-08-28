#!/usr/bin/env bash


if [[ `uname` == "Linux" ]];
then
  sudo systemctl stop nix-daemon.service
  sudo systemctl disable nix-daemon.socket nix-daemon.service
  sudo systemctl daemon-reload
  sudo rm -rf /etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf /nix ~root/.nix-channels ~root/.nix-defexpr ~root/.nix-profile
  for i in $(seq 1 32); do
    sudo userdel nixbld$i
  done
  sudo groupdel nixbld
fi

if [[ `uname` == "Darwin" ]];
then
  [ -e /etc/zshrc.backup-before-nix ] && sudo mv /etc/zshrc.backup-before-nix /etc/zshrc
  [ -e /etc/bashrc.backup-before-nix ] && sudo mv /etc/bashrc.backup-before-nix /etc/bashrc
  [ -e /etc/bash.bashrc.backup-before-nix ] && sudo mv /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc

  [ -e /Library/LaunchDaemons/org.nixos.nix-daemon.plist ] && sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
  [ -e /Library/LaunchDaemons/org.nixos.nix-daemon.plist ] && sudo rm /Library/LaunchDaemons/org.nixos.nix-daemon.plist
  [ -e /Library/LaunchDaemons/org.nixos.darwin-store.plist ] && sudo launchctl unload /Library/LaunchDaemons/org.nixos.darwin-store.plist
  [ -e /Library/LaunchDaemons/org.nixos.darwin-store.plist ] && sudo rm /Library/LaunchDaemons/org.nixos.darwin-store.plist

  sudo dscl . -list /Groups/nixbld && sudo dscl . -delete /Groups/nixbld
  for u in $(sudo dscl . -list /Users | grep _nixbld); do sudo dscl . -delete /Users/$u; done

  sudo rm -rf /etc/nix /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels ~/.nix-profile ~/.nix-defexpr ~/.nix-channels
  diskutil list /nix && sudo diskutil apfs deleteVolume /nix

  echo "Don't forget to edit /etc/fstab with \"vifs\" and /etc/synthetic.conf and remove references to nix"
fi