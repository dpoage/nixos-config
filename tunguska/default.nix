{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./nvidia.nix
    ../modules/core/desktop.nix
    ../modules/dev/cuda.nix
  ];
}