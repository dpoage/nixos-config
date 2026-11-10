# Fuzzel app launcher; fonts, colors and icon theme come from the Stylix
# fuzzel target. `programs.fuzzel` writes ~/.config/fuzzel/fuzzel.ini.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  colors = config.lib.stylix.colors;
  light = config.stylix.polarity == "light";
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
        # light backgrounds. On catppuccin-latte base05 is the only slot
        # reaching 4.5:1 on the selection (base02). Light palettes take
        # base08 for matches and base05 for matches in the selected row.
        colors = lib.mkIf light {
          match = lib.mkForce "${colors.base08}ff";
          selection-match = lib.mkForce "${colors.base05}ff";
        };
        dmenu = {
          exit-immediately-if-empty = "yes";
        };
      };
    };
  };
}
