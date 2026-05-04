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
  };

  outputs = { self, nixpkgs, nixos-hardware, nixvim, home-manager, ... }: {
    nixosConfigurations = {
      tunguska = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixvim.nixosModules.nixvim
          home-manager.nixosModules.home-manager
          ./tunguska
          ./common
        ];
      };
      oerlikon = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixvim.nixosModules.nixvim
          home-manager.nixosModules.home-manager
          ./oerlikon
          ./common
        ];
      };
    };
  };
}
