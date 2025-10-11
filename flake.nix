{
  description = "NixOS configuration for ASUS ROG Zephyrus G14 2025";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      tunguska = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # System-specific configurations
          ./tunguska
          ./common
        ];
      };
    };
  };
}
