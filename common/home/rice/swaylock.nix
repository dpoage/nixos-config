# swaylock-effects lockscreen; colors come from the Stylix swaylock target.
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
      };
    };

    # The screenshots effect is the background, not the wallpaper.
    stylix.targets.swaylock.image.enable = false;
  };
}
