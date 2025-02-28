# https://github.com/koekeishiya/yabai
# https://github.com/koekeishiya/skhd

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.cfg;

  homeDir = builtins.getEnv ("HOME");
  skhd = "/opt/homebrew/bin/skhd";
  skhdrc = "/Users/${cfg.user.name}/.config/skhd/skhdrc";
  yabai = "/opt/homebrew/bin/yabai";
  yabairc = "/Users/${cfg.user.name}/.config/yabai/yabairc";
  path = "/opt/homebrew/bin:/run/current-system/sw/bin:${config.environment.systemPath}";

in {
  imports = [ ./modules.nix ];

  config = {
    homebrew = {
      taps = [ "koekeishiya/formulae" "FelixKratz/formulae" ];
      brews = [ "yabai" "skhd" "borders" ];
    };

    security.accessibilityPrograms = [ "${yabai}" "${skhd}" ];

    launchd.daemons.yabai-sa = {
      script = ''
        if [ ! $(${yabai} --check-sa) ]; then
          ${yabai} --install-sa
        fi
        
        ${yabai} --load-sa
      '';

      serviceConfig.RunAtLoad = true;
      serviceConfig.KeepAlive.SuccessfulExit = false;
    };

    environment.etc."sudoers.d/yabai" = {
      enable = true;
      text = ''
        ${cfg.user.name} ALL = (root) NOPASSWD: ${yabai} --load-sa
      '';
    };

    launchd.user.agents.yabai-sa = {
      serviceConfig.ProgramArguments =
        [ "/usr/bin/sudo" "${yabai}" "--load-sa" ];
      
      serviceConfig.RunAtLoad = true;
      serviceConfig.KeepAlive.SuccessfulExit = false;
    };

    launchd.user.agents.yabai = {
      serviceConfig.ProgramArguments =
        [ "${yabai}" "-c" "${yabairc}" ];
      serviceConfig.KeepAlive = true;
      serviceConfig.ProcessType = "Interactive";
      serviceConfig.EnvironmentVariables = {
        PATH = "${path}";
      };
    };

    launchd.user.agents.skhd = {
      serviceConfig.ProgramArguments =
        [ "${skhd}" "-c" "${skhdrc}" ];
      serviceConfig.KeepAlive = true;
      serviceConfig.ProcessType = "Interactive";
      serviceConfig.EnvironmentVariables = {
        PATH = "${path}";
      };
    };
  };
}
