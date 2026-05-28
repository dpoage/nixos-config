{ pkgs, extraPkgs, ... }:

{
  # NVIDIA developer tooling: profilers + debugger.
  # Imported per-host from each NVIDIA box's default.nix.
  environment.systemPackages = [
    extraPkgs.nsight-systems   # nsys CLI + nsys-ui visualizer
    extraPkgs.nsight-compute   # ncu CLI + ncu-ui visualizer
    extraPkgs.cuda-gdb         # cuda-gdb
  ];
}
