{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/__base.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/desktop-applications.nix
    ../../modules/nixos/digital-audio-workstation.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/flatpak.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/printer.nix
    ../../modules/nixos/virtualbox.nix
  ];

  system.stateVersion = "20.09";
  system.autoUpgrade.channel = "https://channels.nixos.org/nixos-unstable";

  cfg.systemname = "nixos-desktop";
  nix.maxJobs = 16;
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.fstrim.enable = true; # ssd harddrives
  hardware.cpu.amd.updateMicrocode = true; # amd cpus

  hardware.enableRedistributableFirmware = true;
}
