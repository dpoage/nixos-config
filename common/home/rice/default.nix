# Composable rice options shared across hosts.
#
# Each host's home-manager config picks a compositor + palette and toggles
# the program modules it wants. Defaults are conservative: nothing here
# activates unless `myRice.enable` is true, so importing this module is
# a no-op for hosts that haven't opted in.
#
# Example (in a host's home-manager block):
#
#   myRice = {
#     enable = true;
#     palette = "gruvbox";
#     compositor = "niri";
#     wallpaperDir = "/home/dustin/Pictures/Wallpapers/gruvbox/wallpapers";
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  palettes = import ./palettes.nix;

  # Every color key program modules may reference. Adding a new key here
  # forces every palette to define it (eval fails otherwise), and adding
  # a new palette without one of these keys also fails. Catches typos
  # before they ship as blank pixels.
  hexStr = lib.types.strMatching "[0-9a-fA-F]{6}";
  paletteType = lib.types.submodule {
    options = lib.genAttrs [
      # Background ramp
      "bg" "bg0" "bg1" "bg2" "bg3" "bg4"
      # Foreground ramp
      "fg" "fg0" "fg1" "fg2" "fg3" "fg4"
      # Accent ramp (neutral + bright variants)
      "red" "redBr" "green" "greenBr" "yellow" "yellowBr"
      "blue" "blueBr" "purple" "purpleBr" "aqua" "aquaBr"
      "orange" "orangeBr" "gray"
      # Semantic aliases used by program modules
      "accent" "accentSecond" "accentTri" "urgent"
    ] (key: lib.mkOption {
      type = hexStr;
      description = "Hex color (RRGGBB, no leading #) for palette key '${key}'.";
    });
  };
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
    enable = lib.mkEnableOption "the myRice opinionated desktop theming bundle";

    palette = lib.mkOption {
      type = lib.types.enum (lib.attrNames palettes);
      default = "catppuccin";
      description = ''
        Named palette used by every program module. The chosen attrset
        from `palettes.nix` is injected as `config.myRice.colors`.
      '';
    };

    colors = lib.mkOption {
      type = paletteType;
      readOnly = true;
      description = ''
        Resolved colors from the selected palette. Hex without #.
        Strictly typed: missing or malformed keys fail at eval time.
      '';
    };

    compositor = lib.mkOption {
      type = lib.types.enum [ "hyprland" "niri" ];
      default = "hyprland";
      description = ''
        Which Wayland compositor this user's home environment targets.
        The corresponding compositor module is responsible for activating
        only when this matches.
      '';
    };

    wallpaperDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Pictures/Wallpapers";
      description = ''
        Directory the wallpaper helper picks random images from.
        Used by the awww/swww wallpaper daemon integration.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    myRice.colors = palettes.${cfg.palette};
  };
}
