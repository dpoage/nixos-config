# NVIDIA config for Intel + RTX 4060 Max-Q hybrid graphics.
# Options and the actual wiring live in ../common/nvidia.nix.

{ ... }:

{
  myNvidia = {
    enable = true;
    # RTX 40 series handles fine-grained power management without issues.
    finegrained = true;
    busId = {
      intel = "PCI:0:2:0";
      nvidia = "PCI:1:0:0";
    };
  };
}
