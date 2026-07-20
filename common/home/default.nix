{ pkgs, ... }:

{
  imports = [
    ./terminal.nix
    ./hyprland.nix
    ./lock.nix
    ./waybar.nix
    ./dotfiles.nix
    ./dev.nix
    # Opt-in rice bundle: defaults to disabled. Hosts that want the
    # gruvbox+niri (or catppuccin+hyprland) theming set `myRice.enable`
    # in their own home-manager config.
    ./rice
  ];

  home.stateVersion = "25.11";
}
