{ config, lib, pkgs, ... }:

{
  # NVIDIA configuration for Intel + RTX 4060 Max-Q hybrid graphics

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # RTX 40 series supports open kernel modules
    open = true;

    # Enable modesetting for Wayland/HDMI support
    modesetting.enable = true;

    # Power management
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    # Enable nvidia-settings GUI
    nvidiaSettings = true;

    # Use production driver from nixpkgs
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # PRIME configuration for hybrid graphics
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      # Bus IDs from lspci
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # NVIDIA tools
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    nvidia-vaapi-driver
  ];
}
