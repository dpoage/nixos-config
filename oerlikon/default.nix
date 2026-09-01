{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./luks.nix
    ./configuration.nix
    ./storage.nix
    ./nvidia.nix
    ./remote-builder.nix
    ../common/cuda-dev.nix
    # pattern.nix is pulled in transitively via profiles/work.nix.
  ];
}
