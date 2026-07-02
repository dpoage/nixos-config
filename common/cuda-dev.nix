{ pkgs, ... }:

{
  # NVIDIA developer tooling: profilers + debugger.
  # Imported per-host from each NVIDIA box's default.nix.
  environment.systemPackages = [
    pkgs.nsight-systems   # nsys CLI + nsys-ui visualizer
    pkgs.nsight-compute   # ncu CLI + ncu-ui visualizer
    pkgs.cuda-gdb         # cuda-gdb
  ];
}
