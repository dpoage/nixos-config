# Semantic colors for one palette, as 6 hex digits without '#', so app renderers
# never redo contrast math. Dark palettes take their slots as-is; light ones pull
# accents toward the ink by the palette's probed lightContrast percentages.
# `colors` is a Stylix colors set; `lightContrast` is the palette's tuning in default.nix.
{ lib }:
{ colors, lightContrast }:
let
  lc = lightContrast;
  light = colors.variant == "light";
  mix = import ./mix.nix { inherit lib; };
  toward = target: pct: slot: mix.mixHex { from = colors.${slot}; toward = target; inherit pct; };
  pull = toward colors.${lc.ink};
  lightOr = pct: slot: if light then pull pct slot else colors.${slot};
  hint = toward colors.${lc.ink} lc.hint "base00";
in
{
  inherit light hint;
  ink = colors.${lc.ink};

  # Text in `slot`'s hue on base00/base01: 4.5:1 on light palettes.
  fg = lightOr lc.label;
  # Secondary text (base04-ish slots), pulled further on light palettes.
  fgDim = lightOr lc.dim;
  # A chip or segment background in `slot`'s hue that carries base00 text.
  fill = lightOr lc.segment;

  # Dark base08 is 2.7:1 on gruvbox-dark; its bright red clears 4.3:1. Light
  # critical also holds 4.5:1 for base00 text on it.
  danger = if light then pull lc.critical lc.red else colors.base12;
  dangerFill = if light then pull lc.segment lc.red else colors.base12;
  warning = lightOr lc.warning "base09";

  # `hint` is 3:1 on base00: prompt durations and clock, light autosuggestions.
  # Body-text dims: base03/base04 run 1.7-3.4:1 on base00 in dark palettes
  # (mocha base04 is 2.5:1); mixed toward base05, muted holds >= 4.7:1 and dim
  # >= 2.7:1 across the dark palettes.
  muted = if light then pull lc.dim "base04" else toward colors.base05 40 "base04";
  dim = if light then hint else toward colors.base05 30 "base03";

  # Fuzzy-match highlights: base0A on dark palettes. It is 2.2-2.3:1 on light
  # backgrounds, so light palettes take their red, pulled toward the ink.
  match = if light then pull lc.match lc.red else colors.base0A;
  matchSelected = if light then pull lc.selectionMatch lc.red else colors.base0A;
}
