# swaylock-effects lockscreen, themed from the active palette.
# home-manager's programs.swaylock supports `package` override, so we
# swap in swaylock-effects to unlock blur/vignette/clock features.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  c   = cfg.colors;
in
{
  config = lib.mkIf (cfg.enable && cfg.programs.swaylock) {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        ignore-empty-password = true;
        disable-caps-lock-text = true;
        show-failed-attempts = true;

        font = "FantasqueSansM Nerd Font Mono";
        font-size = 24;

        screenshots = true;
        effect-blur = "15x4";
        effect-vignette = "0.4:0.4";
        fade-in = 0.3;

        clock = true;
        timestr = "%I:%M %p";
        datestr = "%A, %d %B";
        indicator = true;
        indicator-radius = 140;
        indicator-thickness = 14;
        indicator-caps-lock = true;

        ring-color = c.accentSecond;
        ring-ver-color = c.blueBr;
        ring-wrong-color = c.urgent;
        ring-clear-color = c.accentTri;
        key-hl-color = c.accent;
        bs-hl-color = c.urgent;
        line-color = "00000000";
        separator-color = "00000000";
        inside-color = "${c.bg}cc";
        inside-ver-color = "${c.bg}cc";
        inside-wrong-color = "${c.bg}cc";
        inside-clear-color = "${c.bg}cc";
        text-color = c.fg;
        text-ver-color = c.fg;
        text-wrong-color = c.redBr;
        text-clear-color = c.fg;
        layout-bg-color = "${c.bg0}aa";
        layout-border-color = c.accentSecond;
        layout-text-color = c.fg;
      };
    };
  };
}
