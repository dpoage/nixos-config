# Gruvbox Dark Hard palette.
#
# Based on morhetz/gruvbox with the "hard" dark background variant.
# Bright accent variants are used for prompt segments (good contrast
# against the near-black promptFg).
{
  meta = {
    name = "Gruvbox Dark Hard";
    variant = "dark";
  };

  fonts = {
    mono = "JetBrainsMono Nerd Font";
    monoSize = 12;
  };

  terminal = {
    opacity = 0.92;
  };

  colors = {
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
    accent       = "fe8019"; # orange — focus, active workspace
    accentSecond = "fabd2f"; # yellow — borders, prompts
    accentTri    = "d3869b"; # pink   — highlights
    urgent       = "cc241d";

    # Prompt segment colors (Starship powerline, FZF highlights)
    promptUser   = "d3869b"; # soft pink — user/os segment
    promptBadge  = "fe8019"; # vivid orange — badge/context segment
    promptPath   = "fabd2f"; # bright yellow — directory segment
    promptVcs    = "b8bb26"; # lime green — git segment
    promptLang   = "8ec07c"; # sage green — language/toolchain segment
    promptInfo   = "83a598"; # teal-blue — cloud/docker segment
    promptMuted  = "b16286"; # muted magenta — time segment
    promptFg     = "1d2021"; # near-black — text on all prompt segments
  };
}
