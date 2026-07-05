{ config, pkgs, ... }:
{
  programs.obs-studio = {
    enable = true;

    # Enable the CUDA‑enabled OBS package only when the system uses the NVIDIA driver
    package = pkgs.obs-studio.override {
      cudaSupport = builtins.elem "nvidia" config.services.xserver.videoDrivers;
    };

    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
    ];
  };
}
