# `pkgs.unstable`, which the other layers' overlays build on. System-independent
# so the flake can export it.
{ inputs }:

final: prev: {
  # Escape hatch: reach any unstable package as `pkgs.unstable.<name>`.
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
}
