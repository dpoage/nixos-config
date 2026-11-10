{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./luks.nix
    ./configuration.nix
    ./storage.nix
    ./nvidia.nix
    ../modules/pattern/desktop.nix
    ../modules/pattern/cuda-dev.nix
  ];
}
