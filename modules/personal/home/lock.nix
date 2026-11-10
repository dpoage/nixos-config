# Styling and compositor gate for the core screen lock (modules/core/home/screen-lock.nix).
{ config, lib, ... }:

let
  colors = config.lib.stylix.colors;
in
{
  config = lib.mkMerge [
    { myScreenLock.enable = lib.mkDefault (config.myRice.compositor == "hyprland"); }

    (lib.mkIf config.myScreenLock.enable {
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
