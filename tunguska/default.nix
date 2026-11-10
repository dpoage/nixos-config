{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./nvidia.nix
    ../modules/pattern/desktop.nix
    ../modules/pattern/cuda-dev.nix
  ];
}