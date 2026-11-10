# Work profile: pattern-cli integration and the apps you actually need
# during the workday. No gaming, no personal multimedia.

{ pkgs, ... }:

{
  imports = [
    ../react-native.nix
  ];

  myUser.extraPackages = with pkgs; [
    # Browsers
    firefox
    chromium
    brave

    # Work communication
    slack
    slack-cli
    signal-desktop
    telegram-desktop

    # Productivity (office suites and mail clients stay web-only: every
    # installed one is a Cyber Essentials patch-tracking item)
    obsidian

    # System tray utilities
    networkmanagerapplet
    pavucontrol
  ];

  # SOC2 compliance stack (Drata agent, ClamAV, Bitwarden) — defined in
  # ../compliance.nix so non-work hosts never carry it.
  patternlabs.compliance.enable = true;
}
