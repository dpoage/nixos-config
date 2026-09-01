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

    # Approved password manager (SOC2 control; Pattern policy: Bitwarden)
    bitwarden-desktop

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

  # SOC2 anti-malware control: clamd resident (~1.2G RAM for the signature
  # DB), freshclam timer for definition updates, and a scheduled clamdscan
  # sweep. On-access scanning (clamonacc) deliberately omitted — the control
  # requires AV presence and periodic scans, not real-time interception.
  # NOTE: like the firewall check, Drata's Linux agent may not auto-detect
  # clamd; if the AV field stays empty after a sync, submit manual evidence
  # (`systemctl status clamav-daemon` + `freshclam --version` screenshot).
  services.clamav = {
    daemon.enable = true;
    updater.enable = true;
    scanner = {
      enable = true;
      # No /tmp,/var/tmp: clamdscan.service runs with PrivateTmp=yes, so
      # those paths resolve to its own empty tmpfs — scanning them is a
      # silent no-op. (Daemon-side sandboxing is irrelevant: the unit uses
      # --fdpass, the scanner opens files and hands clamd the fds.)
      scanDirectories = [ "/home" "/etc" "/var/lib" ];
    };
  };
}
