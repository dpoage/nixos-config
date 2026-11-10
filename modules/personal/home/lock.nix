# Styling and compositor gate for the pattern screen lock (modules/pattern/home/screen-lock.nix).
{ config, lib, ... }:

let
  colors = config.lib.stylix.colors;
in
{
  config = lib.mkMerge [
    { patternlabs.screenLock.enable = lib.mkDefault (config.myRice.compositor == "hyprland"); }

    (lib.mkIf config.patternlabs.screenLock.enable {
      programs.hyprlock.settings.label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(${colors.base05})";
          font_size = 48;
          position = "0, 120";
          halign = "center";
          valign = "center";
        }
      ];

      # Solid-color lock background, not the wallpaper.
      stylix.targets.hyprlock.image.enable = false;
    })
  ];
}
