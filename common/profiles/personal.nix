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
    package = pkgs.asusctl;
  };

  # Inbound access: sshd (key-only) and the whole tailnet trusted. Work
  # hosts get neither — they accept no inbound connections.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # System docker (group membership is root-equivalent). Work hosts use the
  # rootless podman from common/default.nix instead.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  myUser.extraGroups = [ "docker" ];

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
