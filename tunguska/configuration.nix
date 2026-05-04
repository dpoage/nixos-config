{ config, pkgs, ... }:

{
  # Home Manager
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.users.dustin = import ../common/hyprland.nix;

  # Kernel - pinned for NVIDIA compatibility (6.13+ breaks NVIDIA drivers)
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.kernelParams = [
    "amd_pstate=active"
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "nouveau.modeset=0"
    "quiet"
    "splash"
  ];

  networking.hostName = "tunguska";

  # ASUS specific services
  services.asusd = {
    enable = true;
    enableUserService = true;
    package = pkgs.asusctl;
  };

  # Power management (laptop-specific)
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
    };
  };
  services.thermald.enable = true;

  # Touchpad
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      clickMethod = "clickfinger";
      disableWhileTyping = true;
    };
  };

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

  # User account
  users.users.dustin = {
    isNormalUser = true;
    description = "dustin";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" "docker" "render" ];
    packages = with pkgs; [
      # Browsers
      firefox
      chromium
      brave

      # Communication
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

      # Hyprland essentials
      waybar
      wofi
      dunst
      wl-clipboard
      cliphist
      grim
      slurp
      swappy
      hyprpicker
      hyprlock
      hypridle

      # System tray
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
    shell = pkgs.zsh;
  };

  # Device-specific system packages
  environment.systemPackages = with pkgs; [
    (pkgs.writeShellScriptBin "steam-gamescope" ''
      MONITOR_INFO=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.focused == true) | "\(.width)x\(.height)@\(.refreshRate)"')
      WIDTH=$(echo "$MONITOR_INFO" | ${pkgs.coreutils}/bin/cut -d'x' -f1)
      HEIGHT=$(echo "$MONITOR_INFO" | ${pkgs.coreutils}/bin/cut -d'x' -f2 | ${pkgs.coreutils}/bin/cut -d'@' -f1)
      REFRESH=$(echo "$MONITOR_INFO" | ${pkgs.coreutils}/bin/cut -d'@' -f2 | ${pkgs.coreutils}/bin/cut -d'.' -f1)
      echo "Launching Steam in gamescope: ''${WIDTH}x''${HEIGHT}@''${REFRESH}Hz with VRR and HDR"
      exec ${pkgs.gamescope}/bin/gamescope \
        --backend sdl \
        -w "$WIDTH" \
        -h "$HEIGHT" \
        -r "$REFRESH" \
        --adaptive-sync \
        --hdr-enabled \
        -- ${pkgs.steam}/bin/steam "$@"
    '')

    # Laptop utilities
    acpi
    powertop
    brightnessctl
    lm_sensors

    # GPU tools
    glxinfo
    vulkan-tools
    mesa
  ];

  # NVIDIA graphics (extra packages beyond common)
  hardware.graphics.extraPackages = with pkgs; [
    libglvnd
    mesa
  ];
  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
    mesa
  ];

  system.stateVersion = "25.05";
}
