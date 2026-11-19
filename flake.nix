{
  description = "Ojuny Console - Steam Big Picture session and controller-first settings";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-settings-gui = {
      url = "github:ojuny-project/nix-settings-gui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      inherit (lib.fileset) toList fileFilter;

      isNixModule = file: file.hasExt "nix" && file.name != "flake.nix" && !lib.hasPrefix "_" file.name;

      importTree = path: toList (fileFilter isNixModule path);
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = importTree ./modules ++ [
        inputs.flake-parts.flakeModules.modules
        inputs.home-manager.flakeModules.home-manager
      ];

      systems = nixpkgs.lib.systems.flakeExposed;

      flake = {
        nixosModules.default = self.modules.nixos.ojuny-console;
        homeManagerModules.default = self.modules.homeManager.ojuny-console;
        homeModules.default = self.modules.homeManager.ojuny-console;
        lib.annotationCheck = import ./lib/mk-annotation-check.nix { inherit lib; };
      };
    };
}
