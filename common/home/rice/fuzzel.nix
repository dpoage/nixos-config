# Fuzzel app launcher; fonts, colors and icon theme come from the Stylix
# fuzzel target. `programs.fuzzel` writes ~/.config/fuzzel/fuzzel.ini.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
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
        dmenu = {
          exit-immediately-if-empty = "yes";
        };
      };
    };
  };
}
