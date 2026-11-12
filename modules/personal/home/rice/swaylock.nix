# swaylock-effects lockscreen; colors come from the swaylock theme slot, the
# generated config plus each palette's colors.
# home-manager's programs.swaylock supports `package` override, so we
# swap in swaylock-effects to unlock blur/vignette/clock features.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
in
{
  config = lib.mkIf cfg.enable {
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
        line-uses-inside = true;
        scaling = "fill";
      };
    };

    stylix.targets.swaylock.enable = false;
    myTheme.apps.swaylock = {
      render = { colors, ... }:
        let
          inside = colors.base00;
          ring = colors.base01;
          text = colors.base05;
          positive = colors.base0B;
          negative = colors.base08;
        in
        lib.generators.toKeyValue { mkKeyValue = k: v: "${k}=${v}"; } {
          color = inside;
          inside-color = inside;
          inside-clear-color = inside;
          inside-caps-lock-color = inside;
          inside-ver-color = inside;
          inside-wrong-color = inside;
          key-hl-color = positive;
          layout-bg-color = inside;
          layout-border-color = ring;
          layout-text-color = text;
          ring-color = ring;
          ring-clear-color = negative;
          ring-caps-lock-color = ring;
          ring-ver-color = positive;
          ring-wrong-color = negative;
          separator-color = "00000000";
          text-color = text;
          text-clear-color = text;
          text-caps-lock-color = text;
          text-ver-color = text;
          text-wrong-color = text;
        }
        + config.xdg.configFile."swaylock/config".text;
      path = "${config.xdg.configHome}/swaylock/config";
    };
    xdg.configFile."swaylock/config".enable = false;
  };
}
