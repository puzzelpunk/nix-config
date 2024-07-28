{ config, lib, pkgs, options, ... }: {
  config = {
    environment.systemPackages = with pkgs; [ 
      mergerfs 
    ];

    fileSystems = {
      Backup = {
        device = "zpool_BACKUP";
        mountPoint = "/Volumes/Backup";
        fsType = "zfs";
      };

      Server = {
        device = "/dev/disk/by-label/SERVER";
        mountPoint = "/Volumes/Server";
        fsType = "ext4";
      };

      Storage = {
        device = "zpool_STORAGE";
        mountPoint = "/Volumes/Storage";
        fsType = "zfs";
      };

      TimeMachine = {
        device = "/dev/disk/by-label/TIME_MACHINE";
        mountPoint = "/Volumes/TimeMachine";
        fsType = "ext4";
      };

      # Game1 = {
      #   device = "/dev/disk/by-label/GAME_1";
      #   mountPoint = "/Volumes/.GAME/1";
      #   fsType = "ext4";
      # };
      # Game2 = {
      #   device = "/dev/disk/by-label/GAME_2";
      #   mountPoint = "/Volumes/.GAME/2";
      #   fsType = "ext4";
      # };
      # Game3 = {
      #   device = "/dev/disk/by-label/GAME_3";
      #   mountPoint = "/Volumes/.GAME/3";
      #   fsType = "ext4";
      # };
      # Game4 = {
      #   device = "/dev/disk/by-label/GAME_4";
      #   mountPoint = "/Volumes/.GAME/4";
      #   fsType = "ext4";
      # };
      # Game = {
      #   device = "/Volumes/.GAME/*";
      #   mountPoint = "/Volumes/Game";
      #   fsType = "mergerfs";
      #   options = [ 
      #     "defaults" 
      #     "allow_other" 
      #     "use_ino" 
      #     "fsname=Game"
      #   ];
      # };
    };
  };
}
