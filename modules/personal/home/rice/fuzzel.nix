# Fuzzel app launcher; fonts, colors and icon theme come from the Stylix
# fuzzel target. `programs.fuzzel` writes ~/.config/fuzzel/fuzzel.ini.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  colors = config.lib.stylix.colors;
  light = config.stylix.polarity == "light";
  lc = config.myTheme.lightContrast;
  mix = import ../../theme/mix.nix { inherit lib; };
  red = pct: "${mix.mixHex { from = colors.${lc.red}; toward = colors.${lc.ink}; inherit pct; }}ff";
in
{
  config = lib.mkIf cfg.enable {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          prompt = "\">  \"";
          icons-enabled = "yes";
          terminal = "alacritty";
          fields = "name,generic,comment,categories,filename,keywords";
          lines = 12;
          width = 42;
          horizontal-pad = 24;
          vertical-pad = 18;
          inner-pad = 10;
          line-height = 22;
          tabs = 4;
          layer = "overlay";
          exit-on-keyboard-focus-loss = "yes";
        };
        border = {
          width = 2;
          radius = 14;
        };
        # The Stylix fuzzel target's match color is base0A, 2.2-2.3:1 on the
        # light backgrounds; light palettes take their red, pulled toward the ink.
        colors = lib.mkIf light {
          match = lib.mkForce (red lc.match);
          selection-text = lib.mkForce "${colors.${lc.ink}}ff";
          selection-match = lib.mkForce (red lc.selectionMatch);
        };
        dmenu = {
          exit-immediately-if-empty = "yes";
        };
      };
    };
  };
}
