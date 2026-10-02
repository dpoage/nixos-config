# NVIDIA config for ASUS ROG Zephyrus G14 (AMD iGPU + RTX 5080 Max-Q).
# Options and the actual wiring live in ../common/nvidia.nix.

{ ... }:

{
  myNvidia = {
    enable = true;

    # RTX 50 series needs both amdgpu (drives the display) and nvidia (offload).
    videoDrivers = [ "amdgpu" "nvidia" ];

    # finegrained left off — fine-grained PM causes heat issues on the G14.

    busId = {
      amdgpu = "PCI:65:0:0"; # AMD Radeon 880M/890M
      nvidia = "PCI:64:0:0"; # NVIDIA RTX 5080 Max-Q
    };
  };

  # ASUS-specific GPU switching support (host-only).
  services.supergfxd.enable = true;
}
