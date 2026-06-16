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
      # gastown's go.mod requires Go >= 1.26.2; stable nixpkgs only has 1.25.x,
      # so follow unstable (which gastown's own flake targets) for a new enough Go.
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    pattern-cli = {
      url = "git+ssh://git@github.com/Pattern-Labs/pattern_cli";
      inputs.flake-utils.follows = "gastown/flake-utils";
    };
    omp-flake = {
      url = "github:cernoh/omp-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      nixvim,
      home-manager,
      nix-index-database,
      beads,
      gastown,
      pattern-cli,
      omp-flake,
      ...
    }:
    let
      system = "x86_64-linux";
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      extraPkgs = {
        beads = beads.packages.${system}.default;
        claude-code = unstable.claude-code;
        dolt = unstable.dolt;
        opencode = unstable.opencode;
        bun = unstable.bun;
        gastown = gastown.packages.${system}.default.overrideAttrs (old: {
          goModules = old.goModules.overrideAttrs {
            outputHash = "sha256-DHZSRowj1thS/yARB0B5bWMfvegaEAhVB1AI9wfYEDk=";
          };
          # gastown vendors dolt, which pulls in dolthub/go-icu-regex. That package
          # uses cgo and includes <unicode/uregex.h>, linking against -licui18n
          # -licuuc -licudata. Add ICU so the headers and libs are on the search path.
          buildInputs = (old.buildInputs or [ ]) ++ [ unstable.icu ];
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
        # omp-flake wraps the omp binary with `--prefix LD_LIBRARY_PATH`, and the
        # lib set it injects includes glibc. LD_LIBRARY_PATH is inherited by every
        # child process omp spawns, so Go+cgo tools it shells out to (bd, dolt, gt)
        # load the wrong libc and abort with "pthread_create failed: Invalid
        # argument". Re-wrap without glibc — omp's patched interpreter resolves
        # libc on its own, so glibc never needs to be on LD_LIBRARY_PATH.
        omp = omp-flake.packages.${system}.default.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            rm -f "$out/bin/omp"
            makeWrapper "$out/libexec/omp" "$out/bin/omp" \
              --prefix LD_LIBRARY_PATH : "${
                unstable.lib.makeLibraryPath [
                  unstable.stdenv.cc.cc.lib
                  unstable.openssl
                  unstable.zlib
                ]
              }"
          '';
        });

        # NVIDIA developer tooling — pulled from unstable for newer Nsight versions
        # (stable currently ships nsight-systems 2024.6; unstable has 2025.1).
        nsight-systems = unstable.cudaPackages.nsight_systems;
        nsight-compute = unstable.cudaPackages.nsight_compute;
        cuda-gdb = unstable.cudaPackages.cuda_gdb;
      };

      sharedModules = [
        nixvim.nixosModules.nixvim
        home-manager.nixosModules.home-manager
        { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
        ./common
      ];

      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
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
