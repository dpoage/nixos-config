# Catppuccin Mocha palette.
#
# The warm-toned dark variant of Catppuccin. Bright ANSI mappings use
# neighboring Mocha colors so bold/bright text looks intentionally
# distinct rather than just "louder".
{
  meta = {
    name = "Catppuccin Mocha";
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
    # Background ramp
    bg      = "1e1e2e";
    bg0     = "181825";
    bg1     = "313244";
    bg2     = "45475a";
    bg3     = "585b70";
    bg4     = "6c7086";

    # Foreground ramp
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

    # Semantic shortcuts
    accent       = "cba6f7"; # mauve
    accentSecond = "89b4fa"; # blue
    accentTri    = "f5c2e7"; # pink
    urgent       = "f38ba8";

    # Prompt segment colors (Starship powerline, FZF highlights)
    promptUser   = "cba6f7"; # mauve
    promptBadge  = "f2cdcd"; # flamingo
    promptPath   = "fab387"; # peach
    promptVcs    = "a6e3a1"; # green
    promptLang   = "94e2d5"; # teal
    promptInfo   = "89b4fa"; # blue
    promptMuted  = "b4befe"; # lavender
    promptFg     = "11111b"; # crust (darkest)
  };
}
