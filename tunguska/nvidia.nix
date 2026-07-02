# NVIDIA config for ASUS ROG Zephyrus G14 (AMD iGPU + RTX 5080 Max-Q).
# Options and the actual wiring live in ../common/nvidia.nix.

{ config, ... }:

{
  myNvidia = {
    enable = true;

    # RTX 50 series needs both amdgpu (drives the display) and nvidia (offload).
    videoDrivers = [ "amdgpu" "nvidia" ];

    # finegrained left off — fine-grained PM causes heat issues on the G14.

    # Driver 580.95.05 for RTX 50 series support (newer than the nixpkgs default).
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "580.95.05";
      sha256_64bit = "sha256-hJ7w746EK5gGss3p8RwTA9VPGpp2lGfk5dlhsv4Rgqc=";
      openSha256 = "sha256-RFwDGQOi9jVngVONCOB5m/IYKZIeGEle7h0+0yGnBEI=";
      settingsSha256 = "sha256-F2wmUEaRrpR1Vz0TQSwVK4Fv13f3J9NJLtBe4UP2f14=";
      persistencedSha256 = "sha256-QCwxXQfG/Pa7jSTBB0xD3lsIofcerAWWAHKvWjWGQtg=";
    };

    busId = {
      amdgpu = "PCI:65:0:0"; # AMD Radeon 880M/890M
      nvidia = "PCI:64:0:0"; # NVIDIA RTX 5080 Max-Q
    };
  };

  # ASUS-specific GPU switching support (host-only).
  services.supergfxd.enable = true;
}
