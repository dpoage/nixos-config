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
    beads = {
      url = "github:gastownhall/beads";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gastown = {
      url = "github:steveyegge/gastown";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pattern-cli = {
      url = "git+ssh://git@github.com/Pattern-Labs/pattern_cli";
      inputs.flake-utils.follows = "gastown/flake-utils";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, nixvim, home-manager, nix-index-database, beads, gastown, pattern-cli, ... }:
  let
    system = "x86_64-linux";
    unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
    extraPkgs = {
      beads = beads.packages.${system}.default;
      claude-code = unstable.claude-code;
      dolt = unstable.dolt;
      gastown = gastown.packages.${system}.default.overrideAttrs (old: {
        goModules = old.goModules.overrideAttrs {
          outputHash = "sha256-PQT/Xq9na3vI8Oy9INBYJf3GsiN5IxAVCxrNLhyIpO8=";
        };
      });
      gcx = unstable.buildGoModule rec {
        pname = "gcx";
        version = "0.2.15";
        src = unstable.fetchFromGitHub {
          owner = "grafana";
          repo = "gcx";
          tag = "v${version}";
          hash = "sha256-R5uEIgcsrqXYEeflgfSO8Y2k8vuY1xj4WDxK+v2T2ew=";
        };
        vendorHash = "sha256-DxAqHLV7J2mu5x+rQ79NXtkcDkn48u35r7P6sKq2mrY=";
        subPackages = [ "cmd/gcx" ];
      };
      pattern = pattern-cli.packages.${system}.default;
    };

    sharedModules = [
      nixvim.nixosModules.nixvim
      home-manager.nixosModules.home-manager
      { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
      ./common
    ];

    mkHost = hostModule: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit extraPkgs; };
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
