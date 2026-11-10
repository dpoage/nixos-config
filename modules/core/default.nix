# Core layer: the OS baseline every host shares. Hosts additionally import
# ./desktop.nix and ./profiles/* as their hardware and role require.
{ ... }:

{
  imports = [
    ./base.nix
    ./user.nix
    ./nvidia.nix
  ];

  home-manager.sharedModules = [ ./home/screen-lock.nix ];
}
