{ config, lib, pkgs, options, ... }: {
  config.services.samba.shares = {
    TimeMachine = {
      path = "/Volumes/TimeMachine";
      "valid users" = ''"cameron"'';
      "force user" = ''"cameron"'';
      "force group" = ''"cameron"'';
      "fruit:aapl" = "yes";
      "fruit:time machine" = "yes";
      "vfs objects" = "catia fruit streams_xattr";
    };

    Cameron = {
      path = "/Volumes/Storage/Cameron";
       "valid users" = ''"cameron"'';
       "force user" = ''"cameron"'';
       "force group" = ''"cameron"'';
    };

    Rae = {
     path = "/Volumes/Storage/Rae";
       "valid users" = ''"rae","cameron"'';
       "force user" = ''"cameron"'';
       "force group" = ''"cameron"'';
    };

    VSTs = {
      path = "/Volumes/Storage/VSTs";
       "valid users" = ''"cameron"'';
       "force user" = ''"cameron"'';
       "force group" = ''"cameron"'';
    };

    # MNT = {
    #   path = "/mnt";
    #    "valid users" = ''"cameron"'';
    #    "force user" = ''"cameron"'';
    #    "force group" = ''"cameron"'';
    # };
  };
}
