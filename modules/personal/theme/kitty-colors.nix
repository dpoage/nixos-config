# Kitty color settings (`name = "#rrggbb"`) for one myTheme.palettes entry.
{ lib }:
{ colors, roles, ... }:
let
  light = colors.variant == "light";
in
with colors.withHashtag;
{
  foreground = base05;
  background = base00;
  selection_foreground = base00;
  # base06 is rosewater on latte (2.3:1 vs base00); light selections are the
  # inverse chip, and cursor/url follow.
  selection_background = if light then base05 else base06;
  cursor = if light then base05 else base06;
  cursor_text_color = base00;
  url_color = if light then "#${roles.fill "base0D"}" else base06;

  # Tab bar
  active_tab_foreground = base00;
  active_tab_background = base0E;
  inactive_tab_foreground = base05;
  inactive_tab_background = base01;
  tab_bar_background = base00;
}
// lib.listToAttrs (lib.imap0 (i: hex: lib.nameValuePair "color${toString i}" "#${hex}") (import ./ansi.nix colors))
