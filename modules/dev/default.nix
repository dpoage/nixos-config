# Dev layer: language toolchains and build tools. NVIDIA hosts additionally
# import ./cuda.nix.
{ ... }:

{
  imports = [
    ./toolchains.nix
    ./bazel.nix
  ];
}
