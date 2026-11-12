# Mako notification daemon; font from stylix.fonts, colors from the mako theme
# slot, which is the generated config wrapped with each palette's colors.
# `services.mako` generates the INI config and the systemd user service.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  fonts = config.stylix.fonts;
in
{
  config = lib.mkIf cfg.enable {
    stylix.targets.mako.enable = false;

    # Global color keys lead; criteria sections go last, after the generated ones.
    myTheme.apps.mako = {
      render = { colors, ... }: with colors.withHashtag; ''
        background-color=${base00}ff
        border-color=${base0D}
        text-color=${base05}
        progress-color=over ${base02}
        ${config.xdg.configFile."mako/config".text}

        [urgency=low]
        border-color=${base03}

        [urgency=critical]
        border-color=${base08}

        [category=mpd]
        border-color=${base15}
      '';
      path = "${config.xdg.configHome}/mako/config";
      reload = "if ${pkgs.procps}/bin/pgrep -U \"$UID\" mako >/dev/null; then ${config.services.mako.package}/bin/makoctl reload; fi";
    };
    xdg.configFile."mako/config".enable = false;

    services.mako = {
      enable = true;
      settings = {
        font = "${fonts.sansSerif.name} ${toString fonts.sizes.popups}";
        max-visible = 10;
        layer = "overlay";
        anchor = "top-right";
        margin = 16;
        padding = 14;
        default-timeout = 8000;
        max-icon-size = 48;
        icon-location = "left";
        sort = "-time";

        border-size = 2;
        border-radius = 12;
        "urgency=low".default-timeout = 4000;
        "urgency=critical".default-timeout = 0;
        "category=mpd" = {
          default-timeout = 2000;
          group-by = "category";
        };
      };
    };
  };
}
