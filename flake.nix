{
  description = "NixOS configuration for my computers :)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    beads = {
      url = "github:gastownhall/beads";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gastown = {
      url = "github:steveyegge/gastown";
      # gastown's go.mod requires Go >= 1.26.2; stable nixpkgs only has 1.25.x,
      # so follow unstable (which gastown's own flake targets) for a new enough Go.
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    pattern-cli = {
      url = "git+ssh://git@github.com/Pattern-Labs/pattern_cli";
      # pattern's go.mod requires Go >= 1.26.3; stable nixpkgs only has 1.25.x,
      # so follow unstable for a new enough Go (same reasoning as gastown).
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.flake-utils.follows = "gastown/flake-utils";
    };
    omp-flake = {
      url = "github:cernoh/omp-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixvim,
      home-manager,
      nix-index-database,
      ...
    }:
    let
      system = "x86_64-linux";

      # All non-nixpkgs packages (flake inputs + pinned unstable builds) are
      # injected via this overlay, so modules just reference `pkgs.<name>`.
      overlay = import ./overlays { inherit inputs system; };

      sharedModules = [
        nixvim.nixosModules.nixvim
        home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
        { nixpkgs.overlays = [ overlay ]; }
        ./common
      ];

      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = sharedModules ++ [ hostModule ];
        };
    in
    {
      nixosConfigurations = {
        tunguska = mkHost ./tunguska;
        oerlikon = mkHost ./oerlikon;
      };
    };
}
