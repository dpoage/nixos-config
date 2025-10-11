{ config, lib, pkgs, ... }:

{
  # NVIDIA configuration optimized for ASUS ROG Zephyrus G14

  # Enable both AMD (for display) and NVIDIA (for offload) drivers
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  
  hardware.nvidia = {
    # RTX 50 series REQUIRES open-source kernel modules
    open = true;

    # Enable modesetting for better display support
    modesetting.enable = true;

    # Disable fine-grained power management - causes heat issues on G14
    powerManagement.finegrained = false;

    # Enable standard power management instead
    powerManagement.enable = true;
    
    # Enable nvidia-settings GUI
    nvidiaSettings = true;
    
    # Use driver 580.95.05 for RTX 50 series support
    # Manually specified to work on nixos-25.05 (default beta is 575.51.02)
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "580.95.05";
      sha256_64bit = "sha256-hJ7w746EK5gGss3p8RwTA9VPGpp2lGfk5dlhsv4Rgqc=";
      openSha256 = "sha256-RFwDGQOi9jVngVONCOB5m/IYKZIeGEle7h0+0yGnBEI=";
      settingsSha256 = "sha256-F2wmUEaRrpR1Vz0TQSwVK4Fv13f3J9NJLtBe4UP2f14=";
      persistencedSha256 = "sha256-QCwxXQfG/Pa7jSTBB0xD3lsIofcerAWWAHKvWjWGQtg=";
    };
    
    # PRIME configuration for hybrid graphics
    prime = {
      # Enable PRIME offloading for better battery life
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      
      # Bus IDs detected from lspci
      amdgpuBusId = "PCI:65:0:0";   # AMD Radeon 880M/890M
      nvidiaBusId = "PCI:64:0:0";   # NVIDIA RTX 5080 Max-Q
    };
  };
  
  # ASUS-specific GPU switching support
  services.supergfxd.enable = true;
  
  # Essential NVIDIA and monitoring tools
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia  # GPU monitoring
    nvidia-vaapi-driver   # Hardware video acceleration
  ];
  
  # Environment variables for NVIDIA open driver with Wayland
  environment.sessionVariables = {
    # Wayland support
    NIXOS_OZONE_WL = "1";
    # Wayland cursor fix
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
