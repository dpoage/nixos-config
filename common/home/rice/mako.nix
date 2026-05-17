# Mako notification daemon, themed from the active palette.
# Uses home-manager's `services.mako` module which generates the INI
# config and installs a systemd user service.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  c   = cfg.colors;
in
{
  config = lib.mkIf (cfg.enable && cfg.programs.mako) {
    services.mako = {
      enable = true;
      settings = {
        font = "Sarasa UI SC 11";
        max-visible = 10;
        layer = "overlay";
        anchor = "top-right";
        margin = 16;
        padding = 14;
        default-timeout = 8000;
        max-icon-size = 48;
        icon-location = "left";
        sort = "-time";

        background-color = "#${c.bg}ee";
        text-color = "#${c.fg}";
        border-color = "#${c.accentSecond}";
        border-size = 2;
        border-radius = 12;
        progress-color = "over #${c.accent}";

        "urgency=low" = {
          border-color = "#${c.blueBr}";
          default-timeout = 4000;
        };
        "urgency=normal" = {
          border-color = "#${c.accentSecond}";
        };
        "urgency=critical" = {
          border-color = "#${c.urgent}";
          text-color = "#${c.redBr}";
          default-timeout = 0;
        };
        "category=mpd" = {
          border-color = "#${c.aquaBr}";
          default-timeout = 2000;
          group-by = "category";
        };
      };
    };
  };
}
