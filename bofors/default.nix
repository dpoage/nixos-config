{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./ci-vms.nix
  ];
}
