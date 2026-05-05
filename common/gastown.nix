{ pkgs, extraPkgs, ... }:

{
  environment.systemPackages = [
    extraPkgs.gastown
    pkgs.dolt
  ];
}
