# Styling and compositor gate for the core screen lock (modules/core/home/screen-lock.nix).
{ config, lib, ... }:

{
  config = lib.mkMerge [
    { myScreenLock.enable = lib.mkDefault (config.myRice.compositor == "hyprland"); }

    (lib.mkIf config.myScreenLock.enable {
      # Colors are the hyprland theme slot's $theme_* variables (hyprland.nix).
      stylix.targets.hyprlock.enable = false;
      programs.hyprlock.settings = {
        source = [ config.myTheme.apps.hyprland.path ];
        # Solid-color lock background, not the wallpaper.
        background.color = "rgb($theme_base00)";
        input-field = {
          outer_color = "rgb($theme_base03)";
          inner_color = "rgb($theme_base00)";
          font_color = "rgb($theme_base05)";
          fail_color = "rgb($theme_base08)";
          check_color = "rgb($theme_base0A)";
        };
        label = [
          {
            monitor = "";
            text = "$TIME";
            color = "rgb($theme_base05)";
            font_size = 48;
            position = "0, 120";
            halign = "center";
            valign = "center";
          }
        ];
      };
    })
  ];
}
