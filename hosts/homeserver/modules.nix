{ config, pkgs, ... }: {
  imports = [
    ../../modules/common/home/home.nix
    # ../../modules/common/fonts/fonts.nix

    ../../modules/nixos/service-avahi/service-avahi.nix
    ../../modules/nixos/service-cron/service-cron.nix
    ../../modules/nixos/service-docker/service-docker.nix
    ../../modules/nixos/service-firewall/service-firewall.nix
    ../../modules/nixos/service-networking/service-networking.nix
    ../../modules/nixos/service-samba/service-samba.nix
    ../../modules/nixos/service-ssh/service-ssh.nix
    ../../modules/nixos/service-sudo/service-sudo.nix

    ./modules/backups.nix
    # ./modules/desktop-environment.nix
    # ./modules/development.nix
    ./modules/docker-adguard.nix
    ./modules/docker-gitea.nix
    ./modules/docker-nextcloud.nix
    ./modules/docker-resiliosync.nix
    ./modules/docker-swag.nix
    # ./modules/docker-vscode.nix
    # ./modules/docker-copilot-chatgpt.nix
    ./modules/docker-gpt4free.nix
    ./modules/docker.nix
    ./modules/filesystems.nix
    ./modules/networking.nix
    ./modules/samba.nix
    # ./modules/vscode-remote.nix
    ./modules/zfs.nix
  ];
}
