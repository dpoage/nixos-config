# Work profile: pattern-cli integration and the apps you actually need
# during the workday. No gaming, no personal multimedia.
#
# Import this from a host's configuration.nix; the host still owns
# anything machine-specific (hardware, monitors, user identity).

{ config, lib, pkgs, ... }:

{
  imports = [ ../pattern.nix ];

  # Pattern integration takes a username; mirror it from myUser so the
  # primary user only has to be set once per host.
  pattern.primaryUser = lib.mkDefault config.myUser.name;

  myUser.extraPackages = with pkgs; [
    # Browsers
    firefox
    chromium
    brave

    # Work communication
    slack
    signal-desktop
    telegram-desktop
    thunderbird

    # Productivity
    libreoffice-fresh
    obsidian

    # Desktop essentials live in common/desktop.nix and are installed
    # system-wide.

    # System tray utilities
    networkmanagerapplet
    pavucontrol
    blueman
  ];
}
