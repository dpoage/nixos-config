{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/profiles/laptop.nix
    ../common/profiles/personal.nix
    # tunguska keeps both compositors installed so greetd can offer either
    # at login. niri is the daily-driver per myRice below.
    ../common/profiles/hyprland-stack.nix
    ../common/profiles/niri-stack.nix
  ];

  networking.hostName = "tunguska";

  # Kernel pinned for NVIDIA compatibility (6.13+ breaks NVIDIA drivers).
  # Truly host-specific because it depends on this laptop's GPU.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.kernelParams = [
    "amd_pstate=active"
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "nouveau.modeset=0"
    "quiet"
    "splash"
  ];

  # System-level niri: provides the session entry that greetd lists, plus
  # the xdg-desktop-portal-gnome wiring that niri needs. Hyprland from
  # common/desktop.nix stays installed; greetd's default switches below.
  programs.niri.enable = true;
  services.greetd.settings.default_session.command = lib.mkForce
    "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";

  # Primary user + rice preferences for this host.
  myUser = {
    name = "dustin";
    fullName = "dustin";
    home = { ... }: {
      imports = [ ../common/home ];
      myRice = {
        enable = true;
        palette = "gruvbox";
        compositor = "niri";
        wallpaperDir = "/home/dustin/Pictures/Wallpapers/gruvbox/wallpapers";
      };
    };
    # Hyprland tooling now lives in common/desktop.nix so it's available
    # whether the host runs Hyprland or niri; no host-level extras needed.
    extraPackages = [ ];
  };

  # Host-specific helper: launches Steam in a gamescope session sized to
  # whatever monitor Hyprland currently focuses. Stays on the host because
  # it shells out to `hyprctl`, which only works under Hyprland.
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

    # GPU diagnostics (host-specific because dGPU)
    mesa-demos
    vulkan-tools
    mesa
  ];

  # NVIDIA graphics (extra packages beyond common). True host-specific.
  hardware.graphics.extraPackages = with pkgs; [
    libglvnd
    mesa
  ];
  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
    mesa
  ];

  system.stateVersion = "25.05";
}
