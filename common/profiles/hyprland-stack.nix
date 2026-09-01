# Hyprland compositor stack: the WM plus the ecosystem tools that the
# upstream community ships alongside it (lock, idle, picker, default
# launcher/notifier). Import on hosts that actually run Hyprland.
#
# This is intentionally separate from the compositor *enable* line in
# common/desktop.nix because programs.hyprland.enable can stay on for
# the package while a host runs a different compositor at session time.

{ pkgs, ... }:

{
  # hyprlock via the NixOS module so security.pam.services.hyprlock is
  # registered — without the PAM service, unlocking is impossible. The
  # lockscreen config itself is home-manager (common/home/lock.nix).
  programs.hyprlock.enable = true;

  # dconf backing store for the lock-policy mirror in common/home/lock.nix
  # (the Drata compliance agent audits screen lock via gsettings).
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    # Default launcher + notifier for Hyprland
    wofi
    dunst

    # Hyprland-native ecosystem utilities
    hyprpicker
    hypridle
  ];
}
