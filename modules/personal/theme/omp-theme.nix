# omp (oh-my-pi) theme JSON for one palette. Text colors sit on base00; light
# palettes pull them toward the ink like waybar's labels. `colors` is a Stylix
# colors set; `lightContrast` is that palette's myTheme.lightContrast.
{ lib }:
{ colors, lightContrast }:
let
  lc = lightContrast;
  light = colors.variant == "light";
  mix = import ./mix.nix { inherit lib; };
  hash = hex: "#${hex}";
  pulled = pct: slot: hash (mix.mixHex { from = colors.${slot}; toward = colors.${lc.ink}; inherit pct; });

  fg = slot: if light then pulled lc.label slot else hash colors.${slot};
  # Text dims: base03/base04 run 1.7-3.4:1 on base00 in dark palettes (mocha
  # base04 is 2.5:1). Mixed toward base05: muted >= 4.7:1, dim >= 2.7:1 across
  # the dark palettes. Light dim is the starship autosuggest hint (3:1).
  muted = if light then pulled lc.dim "base04"
    else hash (mix.mixHex { from = colors.base04; toward = colors.base05; pct = 40; });
  dim = if light then hash (mix.mixHex { from = colors.base00; toward = colors.${lc.ink}; pct = lc.hint; })
    else hash (mix.mixHex { from = colors.base03; toward = colors.base05; pct = 30; });
  # Dark base08 is 2.7:1 on gruvbox-dark; its bright red clears 4.3:1.
  red = if light then pulled lc.critical lc.red else hash colors.base12;
  warn = if light then pulled lc.warning "base09" else hash colors.base09;
  # Block backgrounds: base00 tinted pct% toward an accent.
  tint = pct: slot: hash (mix.mixHex { from = colors.base00; toward = colors.${slot}; inherit pct; });
  bg = slot: hash colors.${slot};

  accent = fg "base0E";
  green = fg "base0B";
  # Box frames are decoration, not text; base03 as-is.
  frame = hash colors.base03;
in
{
  name = "stylix";
  colors = {
    inherit accent muted dim;
    border = frame;
    borderAccent = accent;
    borderMuted = bg "base02";
    success = green;
    error = red;
    warning = warn;
    # "" is the terminal's own foreground, which kitty/alacritty already set to base05.
    text = "";
    thinkingText = muted;

    selectedBg = bg "base02";
    userMessageBg = bg "base01";
    userMessageText = "";
    customMessageBg = tint 10 "base0E";
    customMessageText = "";
    customMessageLabel = fg "base0C";
    toolPendingBg = bg "base01";
    toolSuccessBg = tint 8 "base0B";
    toolErrorBg = tint 12 lc.red;
    toolTitle = "";
    toolOutput = muted;

    mdHeading = fg "base0D";
    mdLink = fg "base0D";
    mdLinkUrl = dim;
    mdCode = green;
    mdCodeBlock = "";
    mdCodeBlockBorder = frame;
    mdQuote = muted;
    mdQuoteBorder = frame;
    mdHr = frame;
    mdListBullet = accent;

    toolDiffAdded = green;
    toolDiffRemoved = red;
    toolDiffContext = muted;

    # base16 styling guidelines' syntax roles.
    syntaxComment = dim;
    syntaxKeyword = fg "base0E";
    syntaxFunction = fg "base0D";
    syntaxVariable = fg "base08";
    syntaxString = green;
    syntaxNumber = fg "base09";
    syntaxType = fg "base0A";
    syntaxOperator = fg "base0C";
    syntaxPunctuation = muted;

    thinkingOff = bg "base02";
    thinkingMinimal = dim;
    thinkingLow = fg "base0D";
    thinkingMedium = fg "base0C";
    thinkingHigh = fg "base0E";
    thinkingXhigh = fg "base09";
    thinkingMax = red;
    bashMode = fg "base0C";
    pythonMode = fg "base0A";

    # Segment slots follow the starship prompt (terminal.nix).
    statusLineBg = bg "base01";
    statusLineSep = dim;
    statusLineModel = accent;
    statusLinePath = fg "base16";
    statusLineGitClean = green;
    statusLineGitDirty = fg "base0A";
    statusLineContext = fg "base0C";
    statusLineSpend = fg "base17";
    statusLineStaged = green;
    statusLineDirty = fg "base0A";
    statusLineUntracked = red;
    statusLineOutput = fg "base0D";
    statusLineCost = warn;
    statusLineSubagents = accent;
  };
  export = {
    pageBg = bg "base00";
    cardBg = bg "base01";
    infoBg = bg "base02";
  };
  # Colorful markdown paints headings, emphasis and inline code from this palette.
  terminal = {
    background = bg "base00";
    foreground = bg "base05";
    chrome = bg "base01";
    widget = bg "base02";
    ansi = map hash (import ./ansi.nix colors);
  };
}
