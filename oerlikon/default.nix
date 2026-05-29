{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./nvidia.nix
    ../common/cuda-dev.nix
    # pattern.nix is pulled in transitively via profiles/work.nix.
  ];
}
