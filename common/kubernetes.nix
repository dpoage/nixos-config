{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    kind
    kubectx
    # Resource-usage analysis: recommends requests/limits from Prometheus
    # metrics. Patched via overlays/default.nix (broken prometrix dep).
    krr
  ];

  # k9s via home-manager so Stylix's k9s target can skin it.
  home-manager.sharedModules = [ { programs.k9s.enable = true; } ];
}
