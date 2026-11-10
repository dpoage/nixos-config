# Pattern Labs packages. Requires overlays/core for `pkgs.unstable`.
# System-independent so the flake can export it. Stale FOD hashes: run
# `tools/update-hashes.sh`.
{ inputs }:

final: prev:

let
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final) unstable;
in
{
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
      version = builtins.substring 0 8 (inputs.pattern-cli.rev or "dirty");
      pattern-unwrapped = unstable.buildGoModule {
        pname = "pattern";
        inherit version;
        src = inputs.pattern-cli;
        vendorHash = "sha256-YaxaPA3SY96afL8LzJgo/WkWmJI4jZN0KDswIDMgd2E=";
        proxyVendor = true;
        # Private module access inside the goModules FOD (see upstream flake
        # and modules/pattern/cli.nix for the sandbox netrc wiring).
        overrideModAttrs = old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            prev.git
            prev.cacert
          ];
          env.GOPRIVATE = "github.com/Pattern-Labs";
          env.GONOSUMCHECK = "github.com/Pattern-Labs/*";
          # Must match the path modules/pattern/cli.nix sandbox-mounts.
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

  # Go 1.26: gcx 0.2.15's vendored grpc uses http2.TrailerPrefix, which
  # doesn't compile under Go 1.27. Drop the pin when bumping gcx.
  gcx = unstable.buildGo126Module rec {
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

  # Official slackapi CLI (nixpkgs' slack-cli is an unrelated tool). Renamed to
  # avoid clashing with desktop `slack`; self-update can't write the store.
  slack-cli =
    let
      version = "4.10.0";
      arch = { x86_64-linux = "amd64"; aarch64-linux = "arm64"; }.${system};
      hashes = {
        amd64 = "sha256-l3Kxf3DE7FIupq4lVFIg3+F9avtbq+KPoc1Voksqv/o=";
        arm64 = "sha256-qTDgiZd+ETgyDvvjvEncGPQNGHu79KnH/0GcRDvFLTA=";
      };
    in
    final.stdenvNoCC.mkDerivation {
      pname = "slack-cli";
      inherit version;
      src = final.fetchurl {
        url = "https://github.com/slackapi/slack-cli/releases/download/v${version}/slack_cli_${version}_linux_${arch}.tar.gz";
        hash = hashes.${arch};
      };
      sourceRoot = ".";
      nativeBuildInputs = [ final.makeWrapper ];
      installPhase = ''
        install -Dm755 bin/slack $out/libexec/slack
        makeWrapper $out/libexec/slack $out/bin/slack-cli --set-default SLACK_SKIP_UPDATE 1
      '';
      meta = {
        description = "Slack platform CLI";
        homepage = "https://github.com/slackapi/slack-cli";
        license = final.lib.licenses.asl20;
        mainProgram = "slack-cli";
        platforms = [ "x86_64-linux" "aarch64-linux" ];
      };
    };

  # Local repackages: binaries with no nixpkgs derivation.
  # Drata SOC2 agent (Pattern compliance requirement), repacked from the
  # official Ubuntu deb — see ./drata-agent.nix for the asar surgery.
  drata-agent = final.callPackage ./drata-agent.nix { };

  # Stable bitwarden-desktop bundles electron 39, now EOL and refused as insecure.
  bitwarden-desktop = unstable.bitwarden-desktop;
}
