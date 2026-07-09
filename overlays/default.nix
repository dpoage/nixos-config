# Package overlay: adds flake-input packages and selected unstable packages to
# `pkgs`, so every module sees `pkgs.gastown`, `pkgs.gcx`, `pkgs.unstable.<name>`
# etc. without threading a `specialArgs.extraPkgs` set through every signature.
#
# Wired in flake.nix via `nixpkgs.overlays`. To expose a new tool flake-wide,
# add it here — nothing else needs to change.
{ inputs, system }:

final: prev:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  # Escape hatch: reach any unstable package as `pkgs.unstable.<name>`.
  inherit unstable;

  # Flake-input packages
  beads = inputs.beads.packages.${system}.default;
  # pattern shells out to `bazel`. Instead of installing real bazel, put a
  # `bazel` symlink to bazelisk on pattern's PATH (scoped to its wrapper, not
  # system-wide), so bazelisk fetches and runs the workspace-pinned version.
  pattern =
    let
      bazel-shim = prev.runCommand "bazel-shim" { } ''
        mkdir -p $out/bin
        ln -s ${prev.bazelisk}/bin/bazelisk $out/bin/bazel
      '';
    in
    prev.symlinkJoin {
      name = "pattern";
      paths = [ inputs.pattern-cli.packages.${system}.default ];
      nativeBuildInputs = [ prev.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/pattern --prefix PATH : ${bazel-shim}/bin
      '';
    };

  gastown = inputs.gastown.packages.${system}.default.overrideAttrs (old: {
    goModules = old.goModules.overrideAttrs {
      outputHash = "sha256-DHZSRowj1thS/yARB0B5bWMfvegaEAhVB1AI9wfYEDk=";
    };
    # gastown vendors dolt, which pulls in dolthub/go-icu-regex. That package
    # uses cgo and includes <unicode/uregex.h>, linking against -licui18n
    # -licuuc -licudata. Add ICU so the headers and libs are on the search path.
    buildInputs = (old.buildInputs or [ ]) ++ [ unstable.icu ];
  });

  # omp-flake wraps the omp binary with `--prefix LD_LIBRARY_PATH`, and the
  # lib set it injects includes glibc. LD_LIBRARY_PATH is inherited by every
  # child process omp spawns, so Go+cgo tools it shells out to (bd, dolt, gt)
  # load the wrong libc and abort with "pthread_create failed: Invalid
  # argument". Re-wrap without glibc — omp's patched interpreter resolves
  # libc on its own, so glibc never needs to be on LD_LIBRARY_PATH.
  omp = inputs.omp-flake.packages.${system}.default.overrideAttrs (old: {
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

  # Unstable overrides: pin these to unstable's newer builds flake-wide.
  claude-code = unstable.claude-code;
  dolt = unstable.dolt;
  opencode = unstable.opencode;
  bun = unstable.bun;

  # NVIDIA developer tooling — pulled from unstable for newer Nsight versions
  # (stable currently ships nsight-systems 2024.6; unstable has 2025.1).
  nsight-systems = unstable.cudaPackages.nsight_systems;
  nsight-compute = unstable.cudaPackages.nsight_compute;
  cuda-gdb = unstable.cudaPackages.cuda_gdb;
}
