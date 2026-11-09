{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./gate-host.nix
    ./ci-vms.nix
  ];
}
