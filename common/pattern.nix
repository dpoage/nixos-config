{ pkgs, ... }:

{
  imports = [
    ./kubernetes.nix
  ];

  environment.systemPackages = with pkgs; [
    pattern
    bazelisk
  ];
}
