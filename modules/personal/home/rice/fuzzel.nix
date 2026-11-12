# Fuzzel app launcher; colors come from the fuzzel theme slot, which fuzzel
# reads on every launch. `programs.fuzzel` writes ~/.config/fuzzel/fuzzel.ini.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  fonts = config.stylix.fonts;
in
{
  config = lib.mkIf cfg.enable {
    stylix.targets.fuzzel.enable = false;

    myTheme.apps.fuzzel.render = { colors, roles, ... }:
      let
        ink = if roles.light then roles.ink else colors.base05;
      in
      with colors; ''
        [colors]
        background=${base00}ff
        text=${base05}ff
        placeholder=${base03}ff
        prompt=${base05}ff
        input=${base05}ff
        match=${roles.match}ff
        selection=${base02}ff
        selection-text=${ink}ff
        selection-match=${roles.matchSelected}ff
        counter=${base06}ff
        border=${base0D}ff
        # fuzzel.ini continues [main] after the include.
        [main]
        icon-theme=${if roles.light then config.stylix.icons.light else config.stylix.icons.dark}
      '';

    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          include = config.myTheme.apps.fuzzel.path;
          font = "${fonts.sansSerif.name}:size=${toString fonts.sizes.popups}";
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
