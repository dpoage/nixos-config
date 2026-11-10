# Mako notification daemon; font and colors come from the Stylix mako target.
# `services.mako` generates the INI config and the systemd user service.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
in
{
  config = lib.mkIf cfg.enable {
    services.mako = {
      enable = true;
      settings = {
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
          border-color = config.lib.stylix.colors.withHashtag.base15;
          default-timeout = 2000;
          group-by = "category";
        };
      };
    };
  };
}
