# Work profile: pattern-cli integration and the apps you actually need
# during the workday. No gaming, no personal multimedia.

{ pkgs, ... }:

{
  imports = [
    ../pattern.nix
    ../react-native.nix
  ];

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

    # Compliance
    drata-agent
  ];

  # Drata agent autostart: tray app collecting SOC2 evidence; must run for
  # the whole graphical session. hm's hyprland module (systemd.enable
  # defaults true) starts hyprland-session.target, which BindsTo
  # graphical-session.target — so binding there autostarts the agent under
  # Hyprland. Registration note: deep links don't work on unpacked Electron
  # apps, so the first-run magic-link token is pasted into the agent by hand.
  systemd.user.services.drata-agent = {
    description = "Drata SOC2 compliance agent";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.drata-agent}/bin/drata-agent";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
