# Hyprland session lock: hyprlock + hypridle, plus the dconf mirror Drata reads
# via gsettings. Unlock needs programs.hyprlock.enable (profiles/hyprland-stack.nix).

{ config, lib, ... }:

let
  # The dconf idle-delay mirror below must equal this.
  lockTimeout = 300;
in
{
  # hypridle starts with any graphical-session.target, so keep it off under
  # other compositors.
  options.patternlabs.screenLock.enable = lib.mkEnableOption "the Hyprland idle lock";

  config = lib.mkIf config.patternlabs.screenLock.enable {
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
        };

        # Background and input-field colors come from the theme, if any.
        input-field = {
          monitor = "";
          size = "300, 48";
          outline_thickness = 2;
          placeholder_text = "<i>Password...</i>";
          position = "0, 0";
          halign = "center";
          valign = "center";
        };
      };
    };

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          # pidof guard is the upstream-recommended double-lock protection.
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        # No auto-suspend listener on purpose: host power policy stays
        # with tlp/logind (see profiles/laptop.nix).
        listener = [
          {
            timeout = lockTimeout;
            # Route through logind so lock_cmd is the single lock path.
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = lockTimeout + 30;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };

    # Compliance mirror only. Drata's parser splits each gsettings line
    # on spaces and takes the last token, so plain scalar values suffice.
    dconf.settings = {
      "org/gnome/desktop/screensaver" = {
        lock-enabled = true;
        lock-delay = lib.hm.gvariant.mkUint32 0;
      };
      "org/gnome/desktop/session" = {
        idle-delay = lib.hm.gvariant.mkUint32 lockTimeout;
      };
      "org/gnome/system/location" = {
        enabled = false;
      };
    };
  };
}
