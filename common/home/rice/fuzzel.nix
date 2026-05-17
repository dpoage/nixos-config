# Fuzzel app launcher, themed from the active palette.
# Uses home-manager's `programs.fuzzel` module which writes
# ~/.config/fuzzel/fuzzel.ini from a typed `settings` attrset.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  c   = cfg.colors;
in
{
  config = lib.mkIf (cfg.enable && cfg.programs.fuzzel) {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "FantasqueSansM Nerd Font Mono:weight=medium:size=13";
          prompt = "\">  \"";
          icon-theme = "breeze-dark";
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
        # Colors take an 8-char RRGGBBAA hex (no leading #).
        colors = {
          background      = "${c.bg}ee";
          text            = "${c.fg}ff";
          match           = "${c.accentSecond}ff";
          selection       = "${c.bg1}ff";
          selection-text  = "${c.accentSecond}ff";
          selection-match = "${c.accent}ff";
          border          = "${c.accentSecond}ff";
          prompt          = "${c.accent}ff";
          input           = "${c.fg}ff";
          placeholder     = "${c.gray}ff";
          counter         = "${c.gray}ff";
        };
        dmenu = {
          exit-immediately-if-empty = "yes";
        };
      };
    };
  };
}
