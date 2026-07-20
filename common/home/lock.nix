# Screen locking stack for Hyprland sessions: hyprlock (locker) +
# hypridle (idle daemon: lock on timeout, lock before sleep, dpms off).
#
# Gated on myRice.compositor == "hyprland": hyprland.nix's WM settings
# are inert outside a Hyprland session, but hypridle's systemd user unit
# starts with any graphical-session.target — under tunguska's niri it
# would fight the rice swaylock convention (rice/niri.nix).
#
# The dconf block mirrors the lock policy into the GNOME keys the Drata
# compliance agent reads via `gsettings get org.gnome.desktop.screensaver
# ...`; it has no effect on actual locking. Unlock needs a PAM service
# NixOS-side: programs.hyprlock.enable in profiles/hyprland-stack.nix.

{ config, lib, ... }:

let
  c = config.myRice.colors; # resolved palette (default catppuccin)

  # Lock after 5 min idle; screen off 30 s later. The dconf idle-delay
  # mirror below must equal this, so both read the same constant.
  lockTimeout = 300;
in
{
  config = lib.mkIf (config.myRice.compositor == "hyprland") {
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
        };

        background = [
          {
            monitor = "";
            color = "rgb(${c.bg})";
          }
        ];

        label = [
          {
            monitor = "";
            text = "$TIME";
            color = "rgb(${c.fg})";
            font_size = 48;
            position = "0, 120";
            halign = "center";
            valign = "center";
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "300, 48";
            outline_thickness = 2;
            outer_color = "rgb(${c.accent})";
            inner_color = "rgb(${c.bg0})";
            font_color = "rgb(${c.fg})";
            check_color = "rgb(${c.yellow})";
            fail_color = "rgb(${c.urgent})";
            placeholder_text = "<i>Password...</i>";
            position = "0, 0";
            halign = "center";
            valign = "center";
          }
        ];
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
