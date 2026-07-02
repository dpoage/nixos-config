# Maps a resolved palette (ramp keys from palettes/*.nix) to the Catppuccin-style
# semantic color names that the Starship prompt format and Waybar CSS reference.
# Kept in one place so both consumers stay consistent when the palette changes.
#
# Usage: `named = import ./named.nix colors;` -> { mauve = "cba6f7"; ... }
# Values are bare 6-digit hex (no leading '#'), like the palette ramp keys.
colors:

{
  # Background ramp
  base = colors.bg;
  mantle = colors.bg0;
  surface0 = colors.bg1;
  surface1 = colors.bg2;
  surface2 = colors.bg3;
  overlay0 = colors.bg4;

  # Foreground ramp
  text = colors.fg;
  subtext1 = colors.fg2;
  subtext0 = colors.fg3;
  overlay1 = colors.fg4;
  overlay2 = colors.fg4;

  # Accents and prompt segments
  crust = colors.promptFg;
  rosewater = colors.promptBadge;
  flamingo = colors.promptBadge;
  mauve = colors.promptUser;
  pink = colors.accentTri;
  red = colors.redBr;
  maroon = colors.red;
  peach = colors.promptPath;
  yellow = colors.yellow;
  green = colors.promptVcs;
  teal = colors.promptLang;
  sky = colors.aquaBr;
  sapphire = colors.blueBr;
  blue = colors.promptInfo;
  lavender = colors.promptMuted;
  purple = colors.promptMuted;
}
