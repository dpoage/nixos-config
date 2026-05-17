# Niri compositor stack: tools the rice expects when running niri. The
# compositor itself is enabled by `programs.niri.enable = true;` at the
# host level (or via the niri NixOS module), this profile just bundles
# the ecosystem utilities.
#
# myRice already installs fuzzel/mako/swaylock/swww via home-manager
# when the corresponding `myRice.programs.*` are on, so this profile
# only adds the compositor-adjacent CLI helpers that don't fit cleanly
# into home-manager modules.

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Generic wayland utilities (also useful with hyprland but they're
    # not Hyprland-specific so they live here for the niri stack).
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
  ];
}
