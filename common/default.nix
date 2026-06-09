{ lib, pkgs, extraPkgs, ... }:

{
  imports = [
    ./neovim.nix
    ./desktop.nix
    ./bazel.nix
    ./cloud.nix
    ./kubernetes.nix
    ./gastown.nix
    ./myUser.nix
    # Profiles in ./profiles/ are imported directly by each host
    # (laptop + work, workstation + personal, etc.) — not from here.
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.extra-platforms = [ "aarch64-linux" ];

  # QEMU binfmt registration so nix can build aarch64 derivations transparently.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
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
    extraPkgs.claude-code
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
    podman
    lazygit
    extraPkgs.opencode
    bun
    sops
    pkg-config
    ninja

    # Python
    python3
    uv
    ruff

    # Go
    go
    gopls
    golangci-lint
    delve

    # C/C++
    gcc
    gnumake
    cmake
    clang-tools
    gdb

    # Elixir
    elixir
    elixir-ls

    # Rust
    rustup
    rust-analyzer

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
    # nixos-25.11's default docker package is docker_28, marked insecure
    # (unmaintained since Nov 2025). Pin docker_29 instead.
    package = pkgs.docker_29;
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
