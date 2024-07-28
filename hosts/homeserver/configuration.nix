{ config, pkgs, ... }:

let cfg = config.cfg;
in {
  imports = [ ./hardware-configuration.nix ./modules.nix ];
  boot.loader.grub.device = "/dev/nvme0n1";
  boot.loader.grub.enable = true;
  cfg.os.version = "23.11";
  hardware.enableRedistributableFirmware = true;
  nix.settings.auto-optimise-store = true;
  nix.settings.max-jobs = 8;
  programs.zsh.enable = true;
  services.fstrim.enable = true;
  users.groups.rae.name = "rae";
  users.users.rae.group = "rae";
  users.users.rae.isNormalUser = true;
  programs.nix-ld.enable = true;
}
