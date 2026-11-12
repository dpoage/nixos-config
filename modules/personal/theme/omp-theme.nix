# omp (oh-my-pi) theme JSON for one myTheme.palettes entry.
{ lib }:
{ colors, roles, lightContrast, ... }:
let
  hash = hex: "#${hex}";
  mix = import ./mix.nix { inherit lib; };
  # Block backgrounds: base00 tinted pct% toward an accent.
  tint = pct: slot: hash (mix.mixHex { from = colors.base00; toward = colors.${slot}; inherit pct; });
  bg = slot: hash colors.${slot};
  fg = slot: hash (roles.fg slot);

  accent = fg "base0E";
  green = fg "base0B";
  muted = hash roles.muted;
  dim = hash roles.dim;
  red = hash roles.danger;
  warn = hash roles.warning;
  # Box frames are decoration, not text; base03 as-is.
  frame = bg "base03";
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
    toolErrorBg = tint 12 lightContrast.red;
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
