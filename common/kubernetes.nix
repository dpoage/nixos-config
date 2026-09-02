{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    kind
    kubectx
    k9s
    # Resource-usage analysis: recommends requests/limits from Prometheus
    # metrics. Patched via overlays/default.nix (broken prometrix dep).
    krr
  ];
}
