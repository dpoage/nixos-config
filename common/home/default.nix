{ pkgs, ... }:

{
  imports = [
    ./terminal.nix
    ./hyprland.nix
    ./waybar.nix
    ./dotfiles.nix
    ./dev.nix
  ];

  home.stateVersion = "25.11";
}
