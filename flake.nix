{
  description = "nix-configurations";

  inputs = {
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:nix-community/stylix";
  };

  outputs =
    {
      agenix,
      home-manager,
      nix-darwin,
      stylix,
      ...
    }:
    let
      # Auto-discover modules from a directory.
      # Convention: each module is a subdirectory {name}/{name}.nix
      # Sibling files (options.nix, helpers, etc.) are imported by the main module.
      discoverModules =
        dir:
        builtins.listToAttrs (
          builtins.filter (x: x != null) (
            builtins.map (name: (
              let moduleFile = dir + "/${name}/${name}.nix"; in
              if builtins.pathExists moduleFile then
                { inherit name; value = moduleFile; }
              else
                null
            )) (builtins.attrNames (builtins.readDir dir))
          )
        );
    in
    {
      nixosPresets.global = [
        ./modules/global/global.nix
        ./modules/global/nixos.nix
        home-manager.nixosModules.default
        agenix.nixosModules.default
        stylix.nixosModules.stylix
      ];

      darwinPresets.global = [
        ./modules/global/global.nix
        ./modules/global/macos.nix
        home-manager.darwinModules.default
        agenix.darwinModules.default
        stylix.darwinModules.stylix
      ];

      # Individual modules — auto-discovered from directory convention:
      #   modules/nixos/{name}/{name}.nix  →  nixosModules.{name}
      #   modules/macos/{name}/{name}.nix  →  darwinModules.{name}
      # Manually listed for common/ since it has a flat structure.
      nixosModules = discoverModules ./modules/nixos;
      darwinModules = discoverModules ./modules/macos;

      commonModules = {
        home = ./modules/common/home/home.nix;
        dotfiles = ./modules/common/home/dotfiles.nix;
        fonts = ./modules/common/fonts/fonts.nix;
        # Hermes Agent — Home Manager (workstation) preset. Requires the
        # upstream `hermes-agent.homeManagerModules.default` to be imported
        # alongside (see module header).
        hermes = ./modules/common/home/hermes.nix;
      };
    };
}