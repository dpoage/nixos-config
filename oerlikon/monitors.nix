{
  # Monitor layouts for oerlikon (laptop: LG 2560x1600@240)
  # Scenario 1: Dell 4K to the right
  # Scenario 2: Samsung ultrawide to the left
  wayland.windowManager.hyprland.settings.monitor = [
    "desc:LG Display 0x0784, 2560x1600@240, 0x0, 1"
    "desc:Dell Inc. DELL S2722QC, 3840x2160@60, auto-right, 1"
    "desc:Samsung Electric Company LS49AG95, 5120x1440@120, auto-left, 1"
    ", preferred, auto, 1"
  ];
}
