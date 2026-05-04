{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./nvidia.nix
  ];
}
