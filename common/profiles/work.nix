# Work profile: pattern-cli integration and the apps you actually need
# during the workday. No gaming, no personal multimedia.

{ pkgs, ... }:

{
  imports = [ ../pattern.nix ];

  # Inject work-specific prompt badges and cloud context modules.
  # These merge into terminal.nix's myPrompt options via deferredModule.
  myUser.home = { ... }: {
    myPrompt = {
      badges = [
        { icon = ""; label = "Pattern"; }
      ];
      kubernetes = true;
      gcloud = true;
      aws = true;
    };
  };

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
  ];
}
