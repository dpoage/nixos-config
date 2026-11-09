# System-wide color scheme. Every themable surface, NixOS and home-manager,
# reads `myTheme`; it is independent of the myRice desktop bundle.
{ config, lib, pkgs, ... }:

let
  cfg = config.myTheme;
  palettes = lib.mapAttrs (_: f: f { inherit pkgs; }) (import ./palettes);
  p = palettes.${cfg.palette};
  c = p.colors;

  # Every key program modules may reference; each palette must define all of them.
  hexStr = lib.types.strMatching "[0-9a-fA-F]{6}";
  colorsType = lib.types.submodule {
    options = lib.genAttrs [
      "bg" "bg0" "bg1" "bg2" "bg3" "bg4"
      "fg" "fg0" "fg1" "fg2" "fg3" "fg4"
      "red" "redBr" "green" "greenBr" "yellow" "yellowBr"
      "blue" "blueBr" "purple" "purpleBr" "aqua" "aquaBr"
      "orange" "orangeBr" "gray"
      "accent" "accentSecond" "accentTri" "urgent"
      "promptUser" "promptBadge" "promptPath" "promptVcs"
      "promptLang" "promptInfo" "promptMuted" "promptFg"
    ] (key: lib.mkOption {
      type = hexStr;
      description = "Hex color (RRGGBB, no leading #) for palette key '${key}'.";
    });
  };

  generatedWallpaper = pkgs.runCommand "wallpaper-${cfg.palette}.png"
    { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick -size 3840x2160 'radial-gradient:#${c.bg1}-#${c.bg}' \
        \( -background none -density 300 \
           ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg \
           -resize 900x900 -fill '#${c.accent}' -colorize 100 \) \
        -gravity center -composite $out
    '';
in
{
  options.myTheme = {
    palette = lib.mkOption {
      type = lib.types.enum (lib.attrNames palettes);
      default = "catppuccin";
      description = "Named palette (from ./palettes) that themes every surface on the host.";
    };

    colors = lib.mkOption {
      type = colorsType;
      readOnly = true;
      description = "Resolved palette colors, hex without #.";
    };

    named = lib.mkOption {
      type = lib.types.attrsOf hexStr;
      readOnly = true;
      description = "Catppuccin-style semantic names (base, mauve, peach, ...) mapped onto `colors`.";
    };

    ansi = lib.mkOption {
      type = lib.types.listOf hexStr;
      readOnly = true;
      description = "The 16 terminal colors in ANSI order: 0-7 normal, 8-15 bright.";
    };

    meta = lib.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          variant = lib.mkOption { type = lib.types.enum [ "dark" "light" ]; };
        };
      };
      readOnly = true;
      description = "Palette name and dark/light variant.";
    };

    upstream = lib.mkOption {
      type = lib.types.submodule {
        options = {
          nvim = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "nixvim `colorschemes.<name>` module.";
            };
            settings = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
          };
          bat = lib.mkOption {
            type = lib.types.str;
            description = "Built-in bat syntax theme; delta uses it too.";
          };
        };
      };
      readOnly = true;
      description = "Upstream theme names matching the palette, for apps themed by name.";
    };

    fonts = {
      mono = lib.mkOption { type = lib.types.str; };
      monoSize = lib.mkOption { type = lib.types.int; };
    };

    terminal.opacity = lib.mkOption { type = lib.types.float; };

    wallpaper = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      description = ''
        Default wallpaper image. Palettes may ship artwork; otherwise one is
        generated from the palette colors.
      '';
    };
  };

  config = {
    myTheme = {
      colors = c;
      named = import ./named.nix c;
      ansi = [
        c.bg0 c.red c.green c.yellow c.blue c.purple c.aqua c.fg4
        c.gray c.redBr c.greenBr c.yellowBr c.blueBr c.purpleBr c.aquaBr c.fg
      ];
      inherit (p) meta upstream;
      fonts = lib.mapAttrs (_: lib.mkDefault) p.fonts;
      terminal = lib.mapAttrs (_: lib.mkDefault) p.terminal;
      wallpaper = lib.mkDefault "${p.wallpaper or generatedWallpaper}";
    };

    # Linux VT palette; tuigreet draws with it too.
    console.colors = cfg.ansi;

    home-manager.sharedModules = [ ./home.nix ];
  };
}
