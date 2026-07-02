{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.gastown
    pkgs.dolt
  ];

  environment.sessionVariables = {
    GT_TOWN_ROOT = "$HOME/gt";
  };
}
