{ lib, pkgs, extraPkgs, ... }:

{
  imports = [
    ./neovim.nix
    ./desktop.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Timezone & locale
  time.timeZone = "America/Denver";
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

  # Programs
  programs.firefox.enable = true;
  programs.zsh.enable = true;
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
    };
  };
  # Neovim is configured via nixvim in neovim.nix
  # programs.neovim is not used — it conflicts with nixvim's wrapped binary
  programs.nixvim.viAlias = true;
  programs.nixvim.vimAlias = true;

  # System packages
  environment.systemPackages = with pkgs; [
    claude-code
    extraPkgs.beads

    # Core utilities
    wget
    curl
    git
    htop
    btop
    neofetch
    tree
    ripgrep
    fd
    bat
    eza
    zoxide
    fzf
    jq
    yq
    unzip
    zip
    p7zip

    # Terminal & shells
    zsh
    oh-my-zsh
    starship
    tmux
    kitty

    # Development tools
    gcc
    gnumake
    cmake
    python3
    rustup
    go
    bazelisk
    podman
    lazygit
    opencode
    bun
    sops
    kubectl
    kubernetes-helm
    kind

    # System monitoring
    iotop
    nethogs
    bandwhich

    # Network tools
    socat
    tailscale
    nmap
    traceroute
    dig
    whois
    mtr

    # File management
    ranger
    ncdu
    duf

    # Media tools
    ffmpeg
    imagemagick

    # Archive tools
    atool

    # Process management
    killall
    pstree
    lsof

    # Wayland utilities
    wayland-utils
    wlr-randr

    # Keyboard (QMK / Keychron)
    qmk
    qmk_hid
    vial
  ];

  # QMK/Keychron udev rules (allow flashing without root)
  hardware.keyboard.qmk.enable = true;

  # Tailscale
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Services
  services.printing.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.fstrim.enable = true;
  services.fwupd.enable = true;

  # Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Nix maintenance
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "weekly";
  };

  # Security
  security.rtkit.enable = true;
  security.polkit.enable = true;
}
