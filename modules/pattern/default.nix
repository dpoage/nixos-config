# Pattern Labs layer. Hosts additionally import ./desktop.nix, ./cuda-dev.nix
# and ./profiles/* as their hardware and role require.
{ ... }:

{
  imports = [
    ./base.nix
    ./user.nix
    ./devtools.nix
    ./bazel.nix
    ./cloud.nix
    ./kubernetes.nix
    ./hashicorp.nix
    ./nvidia.nix
    ./cli.nix
    ./compliance.nix
  ];

  home-manager.sharedModules = [ ./home/screen-lock.nix ];
}
