{ config, lib, pkgs, options, ... }: {
  system.keyboard.enableKeyMapping = true;
  system.defaults.NSGlobalDomain = {
    AppleMeasurementUnits = config.cfg.localization.measurement;
    AppleTemperatureUnit = config.cfg.localization.temperature;
    NSAutomaticWindowAnimationsEnabled = false;
    NSScrollAnimationEnabled = false;
    NSWindowResizeTime = 1.001;
    NSUseAnimatedFocusRing = false;
    _HIHideMenuBar = false;
    "com.apple.swipescrolldirection" = false;
  };
  system.defaults.alf = {
    stealthenabled = 1;
    loggingenabled = 1;
  };
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.0;
    autohide-time-modifier = 0.0;
    expose-animation-duration = 0.0;
    minimize-to-application = true;
    mru-spaces = false;
    tilesize = 32;
    orientation = "left";
  };
  system.defaults.finder = {
    CreateDesktop = false;
    AppleShowAllExtensions = true;
    FXEnableExtensionChangeWarning = false;
    QuitMenuItem = true;
    _FXShowPosixPathInTitle = true;
  };
  system.defaults.spaces.spans-displays = false;
}
