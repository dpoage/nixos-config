# Dev-layer packages. Requires overlays/core for `pkgs.unstable`.
final: prev: {
  # NVIDIA developer tooling — pulled from unstable for newer Nsight versions
  # (stable currently ships nsight-systems 2024.6; unstable has 2025.1).
  nsight-systems = final.unstable.cudaPackages.nsight_systems;
  nsight-compute = final.unstable.cudaPackages.nsight_compute;
  cuda-gdb = final.unstable.cudaPackages.cuda_gdb;
}
