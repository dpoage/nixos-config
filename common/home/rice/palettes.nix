# Centralized palette definitions for myRice.
#
# Each palette exposes the same keys so program modules can reference them
# uniformly (e.g. `colors.accent`, `colors.bg`). Hex values are stored
# without the leading "#" so callers can format for whichever syntax they
# need (CSS uses `#`, alacritty uses `0x`, swaylock uses bare hex).

{
  gruvbox = {
    # Background ramp (dark hard variant)
    bg      = "1d2021";
    bg0     = "282828";
    bg1     = "3c3836";
    bg2     = "504945";
    bg3     = "665c54";
    bg4     = "7c6f64";

    # Foreground ramp
    fg      = "ebdbb2";
    fg0     = "fbf1c7";
    fg1     = "ebdbb2";
    fg2     = "d5c4a1";
    fg3     = "bdae93";
    fg4     = "a89984";

    # Accent ramp (gruvbox neutral + bright)
    red     = "cc241d";
    redBr   = "fb4934";
    green   = "98971a";
    greenBr = "b8bb26";
    yellow  = "d79921";
    yellowBr = "fabd2f";
    blue    = "458588";
    blueBr  = "83a598";
    purple  = "b16286";
    purpleBr = "d3869b";
    aqua    = "689d6a";
    aquaBr  = "8ec07c";
    orange  = "d65d0e";
    orangeBr = "fe8019";
    gray    = "928374";

    # Semantic shortcuts used by program modules
    accent       = "fe8019"; # orange — used for focus, active workspace
    accentSecond = "fabd2f"; # yellow — used for borders, prompts
    accentTri    = "d3869b"; # pink   — used for highlights
    urgent       = "cc241d";
  };

  catppuccin = {
    # Mocha palette (matches existing terminal/waybar/starship configs)
    bg      = "1e1e2e";
    bg0     = "181825";
    bg1     = "313244";
    bg2     = "45475a";
    bg3     = "585b70";
    bg4     = "6c7086";

    fg      = "cdd6f4";
    fg0     = "ffffff";
    fg1     = "cdd6f4";
    fg2     = "bac2de";
    fg3     = "a6adc8";
    fg4     = "9399b2";

    # Bright variants use neighboring mocha colors so bold text and
    # bright ANSI codes actually look distinct.
    red      = "eba0ac"; # maroon
    redBr    = "f38ba8"; # red
    green    = "a6e3a1";
    greenBr  = "94e2d5"; # teal
    yellow   = "f9e2af";
    yellowBr = "fab387"; # peach
    blue     = "89b4fa";
    blueBr   = "74c7ec"; # sapphire
    purple   = "cba6f7"; # mauve
    purpleBr = "b4befe"; # lavender
    aqua     = "94e2d5"; # teal
    aquaBr   = "89dceb"; # sky
    orange   = "fab387"; # peach
    orangeBr = "f5c2e7"; # pink
    gray     = "6c7086";

    accent       = "cba6f7"; # mauve
    accentSecond = "89b4fa"; # blue
    accentTri    = "f5c2e7"; # pink
    urgent       = "f38ba8";
  };
}
