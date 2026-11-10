{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./luks.nix
    ./configuration.nix
    ./storage.nix
    ./nvidia.nix
    ../modules/core/desktop.nix
    ../modules/dev/cuda.nix
  ];
}
