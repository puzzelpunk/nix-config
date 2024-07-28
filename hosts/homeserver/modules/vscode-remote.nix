{ config, pkgs, ... }: {
  imports = [ (fetchTarball { 
    url = "https://github.com/msteen/nixos-vscode-server/tarball/master";
    sha256 = "0sz8njfxn5bw89n6xhlzsbxkafb6qmnszj4qxy2w0hw2mgmjp829";
  }) ];
  services.vscode-server.enable = true;
  nixpkgs.config.permittedInsecurePackages = [
    "nodejs-16.20.2"
  ];
}
# https://hackmd.io/mLxjbE1jQwydlGXBA3UnkA?view#Solution
# make sure to run this as your user after importing this
# systemctl --user enable auto-fix-vscode-server.service
