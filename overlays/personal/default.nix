# dpoage's packages. Requires overlays/core for `pkgs.unstable`.
{ inputs }:

final: prev:

let
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final) unstable;
in
{
  beads = inputs.beads.packages.${system}.default;

  # Version pin and LD_LIBRARY_PATH wrapper live in the dpoage/omp-flake fork;
  # bump with `nix flake update omp-flake`.
  omp = inputs.omp-flake.packages.${system}.default;

  # b9s: board, tree and dependency graph over beads, as a TUI (`b9s`) and a
  # browser UI (`b9s web`). It reads and writes only through `bd`. The repo
  # vendors its Go modules and commits the built web assets, so no Node step.
  b9s = unstable.buildGoModule rec {
    pname = "b9s";
    version = "1.3.5";
    src = unstable.fetchFromGitHub {
      owner = "vanderheijden86";
      repo = "b9s";
      tag = "v${version}";
      hash = "sha256-l1KAB5dpOWYdici0g+j975K1dES6Q8nwx7YnUs19FFE=";
    };
    vendorHash = null;
    subPackages = [ "cmd/b9s" ];
    ldflags = [
      "-s"
      "-w"
      "-X"
      "github.com/vanderheijden86/b9s/pkg/version.Version=v${version}"
    ];
    meta = {
      description = "Terminal and browser UI for the Beads issue tracker";
      homepage = "https://github.com/vanderheijden86/b9s";
      license = final.lib.licenses.mit;
      mainProgram = "b9s";
    };
  };

  # Bend 2; NVIDIA hosts override cudaSupport (modules/personal/default.nix).
  bend = final.callPackage ./bend.nix { };

  # hyprsplit: nixpkgs 26.05 ships the v0.54.2 tag, which fails against its
  # Hyprland 0.55.4 (g_pConfigManager removed). Upstream main builds against
  # 0.55; no tagged release yet. Drop once nixpkgs' hyprsplit builds again.
  hyprlandPlugins = prev.hyprlandPlugins // {
    hyprsplit = prev.hyprlandPlugins.hyprsplit.overrideAttrs (_: {
      version = "0.54.3-unstable-2026-06-11";
      src = final.fetchFromGitHub {
        owner = "shezdy";
        repo = "hyprsplit";
        rev = "6b00b677d8905fb38779c91e12d6294e0e586a44";
        hash = "sha256-PaoUtmk+qIP/ESdxkxnY7mUMpMHjix88qu22R5GLQqE=";
      };
    });
  };

  # Pin to unstable's newer builds.
  claude-code = unstable.claude-code;
  dolt = unstable.dolt;
  opencode = unstable.opencode;
  bun = unstable.bun;
  # Stable heroic 2.20.1 bundles electron 39, now EOL and refused as insecure.
  # Unstable's 2.22.0 moved to electron 41.7.1 (non-EOL); pin until stable bumps.
  heroic = unstable.heroic;
}
