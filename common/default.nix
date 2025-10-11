{lib, pkgs, ...}:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    claude-code
    
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
    podman
    
    # System monitoring
    iotop
    nethogs
    bandwhich
    
    # Network tools
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
  ];
  
  # Enable zsh as default shell option
  programs.zsh.enable = true;
  
  # Enable git with sensible defaults
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
    };
  };
}
