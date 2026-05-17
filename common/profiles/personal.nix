# Personal machine profile: gaming stack, multimedia, ASUS tools, the
# full personal communication set. Import on machines that aren't
# locked down for work use.

{ pkgs, ... }:

{
  # Gaming
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  # ASUS-specific services (no-op on non-ASUS hardware; safe to leave
  # enabled because asusd just doesn't find a device to talk to).
  services.asusd = {
    enable = true;
    enableUserService = true;
    package = pkgs.asusctl;
  };

  myUser.extraPackages = with pkgs; [
    # Browsers
    firefox
    chromium
    brave

    # Personal communication
    discord
    slack
    signal-desktop
    telegram-desktop

    # Multimedia
    spotify
    vlc
    obs-studio
    gimp
    inkscape

    # Productivity
    libreoffice-fresh
    obsidian
    thunderbird

    # System tray utilities
    networkmanagerapplet
    pavucontrol
    blueman

    # Gaming
    mangohud
    gamemode
    lutris
    heroic

    # ASUS tools
    asusctl
    supergfxctl
  ];
}
