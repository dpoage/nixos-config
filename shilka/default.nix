{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ../modules/core/desktop.nix
  ];
}
