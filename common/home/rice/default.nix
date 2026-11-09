# Opt-in desktop bundle: compositor, bar, launcher, notifications, locker,
# wallpaper daemon. Colors and fonts come from the system-level `myTheme`.

{ config, lib, ... }:

let
  cfg = config.myRice;
in
{
  imports = [
    ./niri.nix
    ./fuzzel.nix
    ./mako.nix
    ./swaylock.nix
    ./alacritty.nix
    ./wallpaper.nix
  ];

  options.myRice = {
    enable = lib.mkEnableOption "the myRice opinionated desktop bundle";

    # --- Compositor & wallpaper ---

    compositor = lib.mkOption {
      type = lib.types.enum [ "hyprland" "niri" ];
      default = "hyprland";
      description = ''
        Which Wayland compositor this user's home environment targets.
        The corresponding compositor module is responsible for activating
        only when this matches.
      '';
    };

    bar = lib.mkOption {
      type = lib.types.enum [ "waybar" "noctalia" "quickshell" "none" ];
      default = "waybar";
      description = ''
        Which status bar / desktop shell to run in the Wayland session.

          - "waybar"    : the themed Waybar config (common/home/waybar.nix).
          - "noctalia"  : the Noctalia Quickshell shell (noctalia-shell).
          - "quickshell": a custom Quickshell config from `quickshellConfig`.
          - "none"      : no bar is autostarted (the host wires its own).

        Exactly one bar module activates on this value; the compositor
        autostart launches `myRice.barCommand` accordingly.
      '';
    };

    quickshellConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a custom Quickshell config directory (containing a
        `shell.qml`). Required when `bar = "quickshell"`; symlinked to
        `~/.config/quickshell` so the `quickshell` binary picks it up.
      '';
    };

    barCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      description = ''
        Resolved autostart command for the selected bar, consumed by the
        compositor modules. `null` when `bar = "none"`.
      '';
    };

    wallpaperDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Pictures/Wallpapers";
      description = ''
        Directory the wallpaper helper picks random images from.
        Used by the awww wallpaper daemon integration.
      '';
    };
  };

  config = {
    # Resolved autostart command per bar choice. `quickshell` reads its
    # config from ~/.config/quickshell (linked by the quickshell module).
    myRice.barCommand = {
      waybar     = "waybar";
      noctalia   = "noctalia-shell";
      quickshell = "quickshell";
      none       = null;
    }.${cfg.bar};
  };
}
