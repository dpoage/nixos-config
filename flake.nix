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
        core = import ./overlays/core { inherit inputs; };
        dev = import ./overlays/dev;
        dev-cloud = import ./overlays/dev-cloud;
        patternlabs = import ./overlays/pattern { inherit inputs; };
        personal = import ./overlays/personal { inherit inputs; };
      };

      # Layers. Each brings its overlay and imports the layers it builds on;
      # `key` dedupes a layer reached through several imports.
      core = {
        key = "nixos-config#core";
        imports = [
          home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          ./modules/core
        ];
        nixpkgs.overlays = [ overlays.core ];
      };

      dev = {
        key = "nixos-config#dev";
        imports = [
          core
          ./modules/dev
        ];
        nixpkgs.overlays = [ overlays.dev ];
      };

      dev-cloud = {
        key = "nixos-config#dev-cloud";
        imports = [
          core
          ./modules/dev-cloud
        ];
        nixpkgs.overlays = [ overlays.dev-cloud ];
      };

      patternlabs = {
        key = "nixos-config#patternlabs";
        imports = [
          core
          dev
          dev-cloud
          ./modules/pattern
        ];
        nixpkgs.overlays = [ overlays.patternlabs ];
      };

      personalModules = [
        core
        nixvim.nixosModules.nixvim
        inputs.stylix.nixosModules.stylix
        { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
        { nixpkgs.overlays = [ overlays.personal ]; }
        # Keep every input's source alive as long as the generation is: the
        # unattended root upgrade (modules/core/base.nix) cannot refetch the
        # git+ssh pattern-cli input once nix.gc has collected it.
        {
          system.extraDependencies = map (i: i.outPath) (
            builtins.attrValues (builtins.removeAttrs inputs [ "self" ])
          );
        }
        ./modules/personal
      ];

      mkHost =
        layers: hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = layers ++ personalModules ++ [ hostModule ];
        };
    in
    {
      overlays = {
        inherit (overlays) core dev dev-cloud patternlabs;
      };

      # Layer modules, plus role modules imported on top of them per host.
      nixosModules = {
        inherit core dev dev-cloud patternlabs;
        core-desktop = ./modules/core/desktop.nix;
        core-laptop = ./modules/core/profiles/laptop.nix;
        core-workstation = ./modules/core/profiles/workstation.nix;
        core-hyprland = ./modules/core/profiles/hyprland-stack.nix;
        dev-cuda = ./modules/dev/cuda.nix;
        patternlabs-work = ./modules/pattern/profiles/work.nix;
      };

      nixosConfigurations = {
        tunguska = mkHost [ dev dev-cloud ] ./tunguska;
        oerlikon = mkHost [ patternlabs ] ./oerlikon;
        bofors = mkHost [ dev dev-cloud ] {
          imports = [
            ./bofors
            inputs.microvm.nixosModules.host
          ];
        };
      };

      # A work laptop for someone else, built from the shared layers alone.
      checks.${system}.patternlabs-example =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = with self.nixosModules; [
            patternlabs
            core-desktop
            core-laptop
            patternlabs-work
            core-hyprland
            ./ci/example-work.nix
          ];
        }).config.system.build.toplevel;
    };
}
