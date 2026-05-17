# Hyprland compositor stack: the WM plus the ecosystem tools that the
# upstream community ships alongside it (lock, idle, picker, default
# launcher/notifier). Import on hosts that actually run Hyprland.
#
# This is intentionally separate from the compositor *enable* line in
# common/desktop.nix because programs.hyprland.enable can stay on for
# the package while a host runs a different compositor at session time.

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Default launcher + notifier for Hyprland
    wofi
    dunst

    # Hyprland-native ecosystem utilities
    hyprpicker
    hyprlock
    hypridle
  ];
}
