{
  description = "NixOS configuration for my computers :)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    nixvim.url = "github:nix-community/nixvim/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    beads = {
      url = "github:gastownhall/beads";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, nixvim, home-manager, nix-index-database, beads, ... }:
  let
    system = "x86_64-linux";
    extraPkgs = {
      beads = beads.packages.${system}.default;
    };
  in
  {
    nixosConfigurations = {
      tunguska = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit extraPkgs; };
        modules = [
          nixvim.nixosModules.nixvim
          home-manager.nixosModules.home-manager
          { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
          ./tunguska
          ./common
        ];
      };
      oerlikon = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit extraPkgs; };
        modules = [
          nixvim.nixosModules.nixvim
          home-manager.nixosModules.home-manager
          { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
          ./oerlikon
          ./common
        ];
      };
    };
  };
}
