{ config, lib, pkgs, ... }:

with lib;
with builtins;
let
  JackConfig = {
    device = "none";
    capture = "none";
    playback = "none";
    rate = 44100;
    periods = 2;
    frames = 1024;
  };

  Packages = with pkgs; [
    a2jmidid
    alsaLib
    # airwave
    bitwig-studio
    musescore
    patchage
    qjackctl
  ];
in {
  config = {
    environment.systemPackages = Packages;
    security.rtkit.enable = true;

    boot = {
      kernelModules = [ "snd-seq" "snd-rawmidi" ];
      kernel.sysctl = {
        "vm.swappiness" = 10;
        "fs.inotify.max_user_watches" = 524288;
      };
      kernelParams = [ "threadirq" ];
      postBootCommands = ''
        echo 2048 > /sys/class/rtc/rtc0/max_user_freq
        echo 2048 > /proc/sys/dev/hpet/max-user-freq
        setpci -v -d *:* latency_timer=b0
        setpci -v -s $(lspci | grep -i audio | awk '{print $1}') latency_timer=ff
      '';
    };

    powerManagement.cpuFreqGovernor = "performance";

    fileSystems."/" = { options = [ "noatime" ]; };

    security.pam.loginLimits = [
      {
        domain = "@audio";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
      {
        domain = "@audio";
        item = "rtprio";
        type = "-";
        value = "99";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "soft";
        value = "99999";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "hard";
        value = "99999";
      }
    ];

    services = {
      # thermald.enable = true;
      udev = {
        extraRules = ''
          KERNEL=="rtc0", GROUP="audio"
          KERNEL=="hpet", GROUP="audio"
        '';
      };
    };

    systemd.user.services.pulseaudio.environment.DISPLAY = ":0";

    environment.variables = {
      VST_PATH =
        "/nix/var/nix/profiles/default/lib/vst:/var/run/current-system/sw/lib/vst:~/.vst";
      LXVST_PATH =
        "/nix/var/nix/profiles/default/lib/lxvst:/var/run/current-system/sw/lib/lxvst:~/.lxvst";
      LADSPA_PATH =
        "/nix/var/nix/profiles/default/lib/ladspa:/var/run/current-system/sw/lib/ladspa:~/.ladspa";
      LV2_PATH =
        "/nix/var/nix/profiles/default/lib/lv2:/var/run/current-system/sw/lib/lv2:~/.lv2";
      DSSI_PATH =
        "/nix/var/nix/profiles/default/lib/dssi:/var/run/current-system/sw/lib/dssi:~/.dssi";
    };

    systemd.user.services.jackaudio = {
      serviceConfig.Type = "simple";
      wantedBy = [ "default.target" ];
      path = with pkgs; [ jack2 a2jmidid pulseaudioFull ];
      environment = { DISPLAY = ":0"; };
      after = [ "pulseaudio.service" ];
      enable = true;
      script = ''
        sleep 5
        jack_control ds alsa
        jack_control dps device '${JackConfig.device}'
        jack_control dps capture '${JackConfig.capture}'
        jack_control dps playback '${JackConfig.playback}'
        jack_control dps rate ${toString JackConfig.rate}
        jack_control dps nperiods ${toString JackConfig.periods}
        jack_control dps period ${toString JackConfig.frames}
        jack_control start
        a2j_control ehw
        a2j_control start
        sleep infinity
      '';
      preStop = ''
        a2j_control exit
        jack_control exit
      '';
    };
  };
}
