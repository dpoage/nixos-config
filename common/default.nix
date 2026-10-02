{ config, lib, pkgs, ... }:

{
  imports = [
    ./neovim.nix
    ./desktop.nix
    ./bazel.nix
    ./cloud.nix
    ./kubernetes.nix
    ./hashicorp.nix
    ./gastown.nix
    ./myUser.nix
    ./nvidia.nix
    ./compliance.nix
    # Profiles in ./profiles/ are imported directly by each host
    # (laptop + work, workstation + personal, etc.) — not from here.
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "@wheel" ];

  # QEMU binfmt registration so nix can build aarch64/riscv64 derivations
  # transparently. The binfmt module also adds these to
  # nix.settings.extra-platforms (plus i686-linux) and wires up the
  # extra-sandbox-paths the emulators need, so no manual extra-platforms here.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];
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
  # Neovim is configured via nixvim in neovim.nix
  # programs.neovim is not used — it conflicts with nixvim's wrapped binary
  programs.nixvim.viAlias = true;
  programs.nixvim.vimAlias = true;

  # System packages
  environment.systemPackages = with pkgs; [
    claude-code
    beads

    # Core utilities
    wget
    curl
    git
    htop
    btop
    fastfetch
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
    lazygit
    opencode
    bun
    omp
    sops
    pkg-config
    ninja

    # Sandboxing — unprivileged namespace jails (`bwrap`); NixOS enables
    # user namespaces by default, so no setuid wrapper is required
    bubblewrap
    landrun # Landlock CLI — unprivileged path/TCP restrictions (kernel 6.12 → ABI v6)
    passt # user-mode net stack (`pasta`) for --unshare-net jails, outbound-only

    # Python
    python3
    uv
    ruff
    pyright

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
    strace # syscall tracing — prerequisite for authoring sandbox policies

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

  # Tailscale (outbound client; inbound trust on the tailnet is a per-profile
  # choice — see profiles/personal.nix)
  services.tailscale.enable = true;

  # Without resolved, tailscaled runs in openresolv mode: it owns
  # /etc/resolv.conf (100.100.100.100) and snapshots NetworkManager's upstream
  # servers from resolvconf on each link change. After a resume/roam it can
  # snapshot before NM has pushed the new lease's DNS, and nothing re-triggers
  # it, so every non-tailnet query SERVFAILs ("no upstream resolvers set")
  # while IP routing works. With resolved, tailscale only sets DNS on
  # tailscale0 and resolved reads NM's per-link servers live — no snapshot.
  services.resolved.enable = true;

  # Services. sshd is not baseline: inbound access is opted into per profile
  # (profiles/personal.nix); work hosts accept no inbound connections.
  services.printing.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;

  # Containers: rootless podman everywhere. Hosts that keep system docker
  # (profiles/personal.nix) get the real `docker` CLI instead of the shim.
  virtualisation.podman = {
    enable = true;
    dockerCompat = !config.virtualisation.docker.enable;
  };

  # sops-nix derives its age identity from services.openssh.hostKeys only
  # while sshd is enabled; name the host key directly so secrets still
  # decrypt on hosts that run no sshd.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Firewall: default deny inbound, allow outbound. Services open their own
  # ports (e.g. services.openssh.openFirewall).
  networking.firewall.enable = true;

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

  # Security patching. The flake lives in the primary user's checkout; the
  # nixpkgs-family inputs are re-resolved to their branch heads on every run
  # without rewriting the committed lock (root never writes into the user's
  # repo). Other inputs stay at their locked revs — pattern-cli is git+ssh and
  # root has no key for it, so it must come from the store (flake.nix keeps
  # every input source alive as a system dependency).
  system.autoUpgrade = {
    enable = true;
    flake = "/home/${config.myUser.name}/code/nixos-config#${config.networking.hostName}";
    upgrade = false;
    flags = [
      "--update-input" "nixpkgs"
      "--update-input" "nixpkgs-unstable"
      "--update-input" "home-manager"
      "--update-input" "nixvim"
      "--no-write-lock-file"
    ];
    allowReboot = false;
    dates = "daily";
    randomizedDelaySec = "45min";
  };

  # Security
  security.rtkit.enable = true;
  security.polkit.enable = true;
}
