{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./remote-builders.nix
    ./nvidia.nix
    ../common/cuda-dev.nix
  ];
}