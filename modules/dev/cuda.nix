{ pkgs, ... }:

{
  # NVIDIA developer tooling: profilers + debugger.
  # Imported per-host by each NVIDIA box.
  environment.systemPackages = [
    pkgs.nsight-systems   # nsys CLI + nsys-ui visualizer
    pkgs.nsight-compute   # ncu CLI + ncu-ui visualizer
    pkgs.cuda-gdb         # cuda-gdb
  ];

  # NixOS CUDA team's cache. cache.nixos.org skips unfree CUDA, so without it
  # every CUDA bump pulls multi-GB archives (nsight_systems alone is 1.2 GB)
  # straight from NVIDIA's CDN.
  nix.settings.extra-substituters = [ "https://cache.nixos-cuda.org" ];
  nix.settings.extra-trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];
}
