{
  description = "NixOS configuration for my computers :)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    nixvim.url = "github:nix-community/nixvim/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
    pattern-cli = {
      url = "git+ssh://git@github.com/Pattern-Labs/pattern_cli";
      # pattern's go.mod requires Go >= 1.26.3; stable nixpkgs only has 1.25.x,
      # so follow unstable for a new enough Go.
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    omp-flake = {
      url = "github:dpoage/omp-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
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

      overlays = {
        patternlabs = import ./overlays/pattern { inherit inputs; };
        personal = import ./overlays/personal { inherit inputs; };
      };

      # The Pattern Labs layer: everything modules/pattern needs, nothing personal.
      patternlabs = {
        imports = [
          home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          ./modules/pattern
        ];
        nixpkgs.overlays = [ overlays.patternlabs ];
      };

      personalModules = [
        nixvim.nixosModules.nixvim
        inputs.stylix.nixosModules.stylix
        { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
        { nixpkgs.overlays = [ overlays.personal ]; }
        # Keep every input's source alive as long as the generation is: the
        # unattended root upgrade (modules/pattern/base.nix) cannot refetch the
        # git+ssh pattern-cli input once nix.gc has collected it.
        {
          system.extraDependencies = map (i: i.outPath) (
            builtins.attrValues (builtins.removeAttrs inputs [ "self" ])
          );
        }
        ./modules/personal
      ];

      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ patternlabs ] ++ personalModules ++ [ hostModule ];
        };
    in
    {
      overlays.patternlabs = overlays.patternlabs;

      # Role modules are imported on top of `patternlabs` per host.
      nixosModules = {
        inherit patternlabs;
        patternlabs-desktop = ./modules/pattern/desktop.nix;
        patternlabs-cuda-dev = ./modules/pattern/cuda-dev.nix;
        patternlabs-laptop = ./modules/pattern/profiles/laptop.nix;
        patternlabs-workstation = ./modules/pattern/profiles/workstation.nix;
        patternlabs-work = ./modules/pattern/profiles/work.nix;
        patternlabs-hyprland = ./modules/pattern/profiles/hyprland-stack.nix;
      };

      nixosConfigurations = {
        tunguska = mkHost ./tunguska;
        oerlikon = mkHost ./oerlikon;
        bofors = mkHost {
          imports = [
            ./bofors
            inputs.microvm.nixosModules.host
          ];
        };
      };

      # A work laptop for someone else, built from the Pattern layer alone.
      checks.${system}.patternlabs-example =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = with self.nixosModules; [
            patternlabs
            patternlabs-desktop
            patternlabs-laptop
            patternlabs-work
            patternlabs-hyprland
            ./ci/example-work.nix
          ];
        }).config.system.build.toplevel;
    };
}
