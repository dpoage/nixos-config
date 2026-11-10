# Shared NVIDIA + PRIME render-offload configuration.
#
# Each NVIDIA host sets `myNvidia` with its PCI bus IDs (and, if needed, a
# pinned driver package); everything else is a sensible default. The whole
# block activates only when `myNvidia.enable = true`, so importing this module
# flake-wide is a no-op for machines without an NVIDIA GPU.
#
# Example (in a host module):
#
#   myNvidia = {
#     enable = true;
#     busId = { intel = "PCI:0:2:0"; nvidia = "PCI:1:0:0"; };
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.myNvidia;
in
{
  options.myNvidia = {
    enable = lib.mkEnableOption "NVIDIA graphics with PRIME render offload";

    open = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use the open-source kernel modules (required for RTX 40/50 series).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.nvidiaPackages.stable;
      defaultText = lib.literalExpression "config.boot.kernelPackages.nvidiaPackages.stable";
      description = ''
        NVIDIA driver package. Override for hardware that needs a newer or
        pinned driver than the nixpkgs default (e.g. RTX 50 series).
      '';
    };

    finegrained = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable fine-grained (per-GPU) power management. Leave off on hardware
        where it causes heat or stability issues (e.g. ASUS ROG G14).
      '';
    };

    videoDrivers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nvidia" ];
      description = ''
        X server video drivers. Put the iGPU driver ("amdgpu"/"modesetting")
        ahead of "nvidia" on hybrid systems where the iGPU drives the display.
      '';
    };

    busId = {
      nvidia = lib.mkOption {
        type = lib.types.str;
        example = "PCI:1:0:0";
        description = "PCI bus ID of the NVIDIA GPU (from lspci).";
      };
      intel = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "PCI bus ID of the Intel iGPU, if present.";
      };
      amdgpu = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "PCI bus ID of the AMD iGPU, if present.";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional GPU-related packages installed on this host.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = cfg.videoDrivers;

    hardware.nvidia = {
      open = cfg.open;
      modesetting.enable = true;
      nvidiaSettings = true;
      powerManagement.enable = true;
      powerManagement.finegrained = cfg.finegrained;
      package = cfg.package;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        nvidiaBusId = cfg.busId.nvidia;
      }
      // lib.optionalAttrs (cfg.busId.intel != "") { intelBusId = cfg.busId.intel; }
      // lib.optionalAttrs (cfg.busId.amdgpu != "") { amdgpuBusId = cfg.busId.amdgpu; };
    };

    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia   # GPU monitoring
      nvidia-vaapi-driver    # Hardware video acceleration
    ] ++ cfg.extraPackages;
  };
}
