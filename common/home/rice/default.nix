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
  palettes = import ./palettes;

  # Every color key program modules may reference. Adding a new key here
  # forces every palette to define it (eval fails otherwise), and adding
  # a new palette without one of these keys also fails. Catches typos
  # before they ship as blank pixels.
  hexStr = lib.types.strMatching "[0-9a-fA-F]{6}";
  colorsType = lib.types.submodule {
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
      # Prompt segment colors (Starship powerline, FZF)
      "promptUser" "promptBadge" "promptPath" "promptVcs"
      "promptLang" "promptInfo" "promptMuted" "promptFg"
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
        Named palette used by every program module. The chosen palette
        from `palettes/` is injected as `config.myRice.colors` (and
        sets defaults for fonts, terminal opacity, etc.).
      '';
    };

    # --- Identity (readOnly, determined by palette) ---

    colors = lib.mkOption {
      type = colorsType;
      readOnly = true;
      description = ''
        Resolved colors from the selected palette. Hex without #.
        Strictly typed: missing or malformed keys fail at eval time.
      '';
    };

    meta = lib.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Human-readable palette name.";
          };
          variant = lib.mkOption {
            type = lib.types.enum [ "dark" "light" ];
            description = "Whether the palette is dark or light background.";
          };
        };
      };
      readOnly = true;
      description = "Palette metadata — name and dark/light variant.";
    };

    # --- Preferences (overridable per-host) ---

    fonts = lib.mkOption {
      type = lib.types.submodule {
        options = {
          mono = lib.mkOption {
            type = lib.types.str;
            description = "Monospace font family for terminals and editors.";
          };
          monoSize = lib.mkOption {
            type = lib.types.int;
            description = "Default monospace font size in points.";
          };
        };
      };
      description = ''
        Font preferences. Defaults come from the palette but can be
        overridden per-host (e.g. larger fonts on a high-DPI display).
      '';
    };

    terminal = lib.mkOption {
      type = lib.types.submodule {
        options = {
          opacity = lib.mkOption {
            type = lib.types.float;
            description = "Terminal background opacity (0.0–1.0).";
          };
        };
      };
      description = ''
        Terminal preferences. Defaults come from the palette but can
        be overridden per-host.
      '';
    };

    # --- Compositor & wallpaper (unchanged) ---

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

  config = lib.mkIf cfg.enable (let p = palettes.${cfg.palette}; in {
    myRice.colors   = p.colors;
    myRice.meta     = p.meta;
    # mkDefault so hosts can override fonts/terminal without fighting
    myRice.fonts    = lib.mkDefault p.fonts;
    myRice.terminal = lib.mkDefault p.terminal;
  });
}
