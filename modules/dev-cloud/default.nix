# Dev-cloud layer: cloud provider CLIs, Kubernetes, and the HashiCorp suite.
{ ... }:

{
  imports = [
    ./cloud.nix
    ./kubernetes.nix
    ./hashicorp.nix
  ];
}
