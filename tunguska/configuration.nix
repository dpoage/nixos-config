{ config, pkgs, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use kernel 6.12 for NVIDIA compatibility (6.13+ breaks NVIDIA drivers)
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  
  # ASUS G14 specific kernel parameters
  boot.kernelParams = [
    "amd_pstate=active"
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "nouveau.modeset=0"
    "quiet"
    "splash"
  ];

  networking.hostName = "tunguska";
  
  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Denver";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.xwayland.enable = true;


  # Enable display manager
  services.xserver.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };
  
  # XDG portal for Wayland
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  # Configure keymap in X11 (still needed for some apps)
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # ASUS specific services
  services.asusd = {
    enable = true;
    enableUserService = true;
    package = pkgs.asusctl;  # Ensure both services use the same package
  };
  
  # Power management for laptops
  services.power-profiles-daemon.enable = false; # Conflicts with TLP
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      
      # USB autosuspend
      USB_AUTOSUSPEND = 1;
      
      # WiFi power saving
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
    };
  };
  
  # Thermald for thermal management
  services.thermald.enable = true;

  programs = {
    neovim = {
      enable = true;
      package = pkgs.neovim-unwrapped;
      vimAlias = true;
    };

    gamescope = {
      enable = true;
      capSysNice = true;
    };

    # Steam for gaming
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Enable touchpad support
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      clickMethod = "clickfinger";
      disableWhileTyping = true;
    };
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
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

      # Gaming utilities
      mangohud
      gamemode
      lutris
      heroic
      
      # ASUS tools
      asusctl
      supergfxctl
      
      # Hyprland essentials
      waybar              # Status bar
      wofi                # Application launcher
      dunst               # Notification daemon
      wl-clipboard        # Wayland clipboard utilities
      cliphist            # Clipboard manager
      grim                # Screenshot utility
      slurp               # Screen area selector
      swappy              # Screenshot annotation
      hyprpicker          # Color picker
      hyprlock            # Lock screen
      hypridle            # Idle daemon
      
      # System tray apps
      networkmanagerapplet
      pavucontrol
      blueman
    ];
    shell = pkgs.zsh;
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Steam gamescope wrapper with VRR and HDR
    (pkgs.writeShellScriptBin "steam-gamescope" ''
      # Get active monitor resolution from Hyprland
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

    # System utilities specific to laptop
    acpi
    powertop
    brightnessctl
    
    # Firmware updates
    fwupd
    
    # Sensors
    lm_sensors
    
    # GPU debugging tools
    glxinfo
    vulkan-tools

    # Mesa OpenGL drivers
    mesa

    # Wayland utilities
    wayland-utils
    wlr-randr
    
    # Fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    font-awesome
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.sauce-code-pro
    nerd-fonts.iosevka
    nerd-fonts.ubuntu-mono
    nerd-fonts.roboto-mono
    nerd-fonts.meslo-lg
    nerd-fonts.inconsolata
    nerd-fonts.victor-mono
  ];
  
  # Font configuration
  fonts = {
    enableDefaultPackages = true;
    fontconfig = {
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  # Enable firmware updates
  services.fwupd.enable = true;
  
  # Enable OpenGL and Vulkan
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libglvnd
      mesa
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      mesa
    ];
  };

  # Enable bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
  
  # Enable Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH
  };
  
  # Enable automatic system upgrades
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "weekly";
  };
  
  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # Enable SSD TRIM
  services.fstrim.enable = true;
  
  # Polkit authentication agent
  security.polkit.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.05"; # Did you read the comment?
}
