{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./nvidia.nix
    ../common/desktop.nix
    ../common/cuda-dev.nix
  ];
}