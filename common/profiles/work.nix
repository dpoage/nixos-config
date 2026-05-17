# Work profile: pattern-cli integration and the apps you actually need
# during the workday. No gaming, no personal multimedia.

{ pkgs, ... }:

{
  imports = [ ../pattern.nix ];

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

    # System tray utilities
    networkmanagerapplet
    pavucontrol
    blueman
  ];
}
