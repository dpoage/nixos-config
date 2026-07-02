{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    kind
    kubectx
    k9s
  ];
}
