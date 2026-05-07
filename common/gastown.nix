{ pkgs, extraPkgs, ... }:

{
  environment.systemPackages = [
    extraPkgs.gastown
    extraPkgs.dolt
  ];

  environment.sessionVariables = {
    GT_TOWN_ROOT = "$HOME/gt";
  };
}
