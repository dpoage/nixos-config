# Package overlay: adds flake-input packages and selected unstable packages to
# `pkgs`, so every module sees `pkgs.gastown`, `pkgs.gcx`, `pkgs.unstable.<name>`
# etc. without threading a `specialArgs.extraPkgs` set through every signature.
#
# Wired in flake.nix via `nixpkgs.overlays`. To expose a new tool flake-wide,
# add it here — nothing else needs to change.
#
# Stale FOD hashes (goModules outputHash, release binaries, vendorHash)?
# Run `tools/update-hashes.sh` — see its header for version-bump flags.
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
  #
  # We build pattern ourselves instead of using pattern-cli's packaged output:
  # upstream's flake hardcodes buildGo125Module while its go.mod requires
  # Go >= 1.26.3, so the upstream package cannot build. Attrs below mirror
  # upstream's flake.nix (vendorHash pinned here so update-hashes.sh manages
  # it). Drop this once upstream moves to a new enough Go builder.
  pattern =
    let
      bazel-shim = prev.runCommand "bazel-shim" { } ''
        mkdir -p $out/bin
        ln -s ${prev.bazelisk}/bin/bazelisk $out/bin/bazel
      '';
      version = builtins.substring 0 8 inputs.pattern-cli.rev;
      pattern-unwrapped = unstable.buildGoModule {
        pname = "pattern";
        inherit version;
        src = inputs.pattern-cli;
        vendorHash = "sha256-yc8TfGI2wXaSv6tfTsMGGH2BOJJXmnBqyY/DtNlMc2A=";
        proxyVendor = true;
        # Private module access inside the goModules FOD (see upstream flake
        # and common/pattern.nix for the sandbox netrc wiring).
        overrideModAttrs = old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            prev.git
            prev.cacert
          ];
          env.GOPRIVATE = "github.com/Pattern-Labs";
          env.GONOSUMCHECK = "github.com/Pattern-Labs/*";
          # Must match the path common/pattern.nix sandbox-mounts.
          env.NETRC = "/etc/nix/netrc";
        };
        subPackages = [ "cmd/pattern" ];
        env.CGO_ENABLED = "0";
        ldflags = [
          "-s"
          "-w"
          "-X"
          "github.com/Pattern-Labs/pattern_cli/pkg/version.Version=${version}"
        ];
        meta = {
          description = "Pattern Labs internal CLI";
          mainProgram = "pattern";
        };
      };
    in
    prev.symlinkJoin {
      name = "pattern";
      paths = [ pattern-unwrapped ];
      nativeBuildInputs = [ prev.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/pattern --prefix PATH : ${bazel-shim}/bin
      '';
    };

  gastown = inputs.gastown.packages.${system}.default.overrideAttrs (old: {
    goModules = old.goModules.overrideAttrs {
      outputHash = "sha256-ZUEQQ0br+5UQnk/XLM7NLDCd1qA93VOho1iQ3q3RUm8=";
    };
    # gastown vendors dolt, which pulls in dolthub/go-icu-regex. That package
    # uses cgo and includes <unicode/uregex.h>, linking against -licui18n
    # -licuuc -licudata. Add ICU so the headers and libs are on the search path.
    buildInputs = (old.buildInputs or [ ]) ++ [ unstable.icu ];
  });

  # omp-flake hardcodes an oh-my-pi release (URL + sha256 per platform) in its
  # own flake.nix and lags behind releases. We already track omp-flake's HEAD,
  # so `nix flake update omp-flake` is a no-op when upstream hasn't bumped —
  # instead we pin the release binary ourselves. Bump with:
  #   tools/update-hashes.sh --omp-version <ver>
  #
  # The postFixup re-wrap fixes a glibc-inheritance bug: omp-flake wraps the omp
  # binary with `--prefix LD_LIBRARY_PATH`, and the lib set it injects includes
  # glibc. LD_LIBRARY_PATH is inherited by every child process omp spawns, so
  # Go+cgo tools it shells out to (bd, dolt, gt) load the wrong libc and abort
  # with "pthread_create failed: Invalid argument". Re-wrap without glibc — omp's
  # patched interpreter resolves libc on its own, so glibc never needs to be on
  # LD_LIBRARY_PATH.
  omp =
    let
      ompVersion = "18.1.6";
      ompSources = {
        x86_64-linux = {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v${ompVersion}/omp-linux-x64";
          hash = "sha256-+UO2qtrzOaO6yjXkOuc4adqE6abiwH2uFcdN18asT7A=";
        };
        aarch64-linux = {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v${ompVersion}/omp-linux-arm64";
          hash = "sha256-lhhgfrJHN+U/St23aUNKJfmSA8ZcnSNPtMlbclHUQO4=";
        };
        x86_64-darwin = {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v${ompVersion}/omp-darwin-x64";
          hash = "sha256-mHsyOiIdSOfXE1VfLz1ySNUB++5DqXA9jzlng2MdssA=";
        };
        aarch64-darwin = {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v${ompVersion}/omp-darwin-arm64";
          hash = "sha256-XfmJgjUYnJUxkD0IXajPqDBt/iDR7WxBSVeH1PJVhx0=";
        };
      };
    in
    inputs.omp-flake.packages.${system}.default.overrideAttrs (old: {
      version = ompVersion;
      src = final.fetchurl ompSources.${system};
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

  # Local repackages: binaries with no nixpkgs derivation.
  # Drata SOC2 agent (Pattern compliance requirement), repacked from the
  # official Ubuntu deb — see ./drata-agent.nix for the asar surgery.
  drata-agent = final.callPackage ./drata-agent.nix { };

  # krr (Robusta's Kubernetes Resource Recommender): unbuildable as shipped.
  # nixpkgs' prometrix (0.1.18-unstable) requires pydantic 2 and is marked
  # broken against prometheus-api-client >= 0.5.3, while krr itself pins
  # pydantic 1 — so the stock pairing can never work. krr's own poetry.lock
  # resolves prometrix 0.1.10 (pydantic 1 native); pin that release from PyPI
  # inside krr's python scope. Two fixups on top:
  #  - prometheus-api-client >= 0.5.3 removed the `ssl_verification` attribute
  #    prometrix reads (robusta-dev/prometrix#14). It was defined as
  #    `not disable_ssl`, so patch the references to compute that from
  #    prometrix's own config.
  #  - relax the prometheus-api-client < 0.6 cap (scope ships 0.6.0).
  # Drop this once nixpkgs' prometrix/krr pairing builds again.
  krr =
    (prev.krr.override {
      python3 = prev.python3.override {
        packageOverrides = pyfinal: pyprev: {
          prometrix = pyprev.prometrix.overridePythonAttrs (old: {
            version = "0.1.10";
            src = final.fetchPypi {
              pname = "prometrix";
              version = "0.1.10";
              hash = "sha256-ntYcC3e1A9OM6cZtcHQq2BqEt6/G+/Y+jbupMWtBpN8=";
            };
            postPatch = ''
              substituteInPlace prometrix/connect/custom_connect.py prometrix/connect/aws_connect.py \
                --replace-fail "self.ssl_verification" "(not self.config.disable_ssl)"
            '';
            dependencies = with pyfinal; [
              boto3
              botocore
              prometheus-api-client
              pydantic_1
              requests
            ];
            pythonRelaxDeps = [ "prometheus-api-client" ];
            meta = old.meta // {
              broken = false;
            };
          });
        };
      };
    }).overridePythonAttrs
      (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [
          "numpy"
          "prometheus-api-client"
        ];
        # Two click-8.2 fixups (krr pins typer ^0.7 / click <8.2 upstream;
        # nixpkgs relaxes those pins):
        #  - CliRunner(mix_stderr=...) was removed; stderr is separate by
        #    default now, which is what mix_stderr=False asked for.
        #  - unset multi-value options now yield None instead of (), which
        #    crashes `"*" in namespaces` and Config's headers validator.
        #    Substitute [] — Config's validators map [] to the "*"/{} defaults
        #    exactly as the old () did.
        postPatch = (old.postPatch or "") + ''
          substituteInPlace tests/test_krr.py \
            --replace-fail "CliRunner(mix_stderr=False)" "CliRunner()"
          substituteInPlace robusta_krr/main.py \
            --replace-fail \
              'namespaces="*" if "*" in namespaces else namespaces' \
              'namespaces="*" if "*" in (namespaces or []) else (namespaces or [])' \
            --replace-fail \
              'resources="*" if "*" in resources else resources' \
              'resources="*" if "*" in (resources or []) else (resources or [])' \
            --replace-fail \
              'prometheus_other_headers=prometheus_other_headers,' \
              'prometheus_other_headers=prometheus_other_headers or [],'
        '';
      });

  # Unstable overrides: pin these to unstable's newer builds flake-wide.
  claude-code = unstable.claude-code;
  dolt = unstable.dolt;
  opencode = unstable.opencode;
  bun = unstable.bun;
  # Stable heroic 2.20.1 bundles electron 39, now EOL and refused as insecure.
  # Unstable's 2.22.0 moved to electron 41.7.1 (non-EOL); pin until stable bumps.
  heroic = unstable.heroic;
  # Same electron-EOL story: stable bitwarden-desktop bundles electron 39.
  bitwarden-desktop = unstable.bitwarden-desktop;

  # NVIDIA developer tooling — pulled from unstable for newer Nsight versions
  # (stable currently ships nsight-systems 2024.6; unstable has 2025.1).
  nsight-systems = unstable.cudaPackages.nsight_systems;
  nsight-compute = unstable.cudaPackages.nsight_compute;
  cuda-gdb = unstable.cudaPackages.cuda_gdb;
}
