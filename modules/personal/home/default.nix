{ pkgs, ... }:

{
  imports = [
    ./terminal.nix
    ./hyprland.nix
    ./lock.nix
    ./waybar.nix
    ./noctalia.nix
    ./quickshell.nix
    ./dotfiles.nix
    ./omp.nix
    ./dev.nix
    # Opt-in desktop bundle (myRice.enable); colors come from Stylix.
    ./rice
  ];

  home.stateVersion = "25.11";
}
