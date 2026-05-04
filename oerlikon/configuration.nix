{ config, pkgs, ... }:

{
  networking.hostName = "oerlikon";

  # Home Manager
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.users.dpoage = import ../common/home;

  # User account
  users.users.dpoage = {
    isNormalUser = true;
    description = "Dustin";
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
    ];
    shell = pkgs.zsh;
  };

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

  system.stateVersion = "25.11";
}
