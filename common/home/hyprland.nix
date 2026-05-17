{ config, lib, pkgs, ... }:

let
  wallpaper = "${pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha-alt}/share/backgrounds/nixos/nix-wallpaper-nineish-catppuccin-mocha-alt.png";
in
{
  # Wallpaper via hyprpaper. Disabled when myRice owns the wallpaper —
  # rice runs swww and the two daemons fight over the layer surface.
  services.hyprpaper = lib.mkIf (!(config.myRice.enable or false)) {
    enable = true;
    settings = {
      preload = [ wallpaper ];
      wallpaper = [ ", ${wallpaper}" ];
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    plugins = [
      pkgs.hyprlandPlugins.hyprsplit
    ];

    settings = {
      # Monitor config - generic fallback, hosts add specific rules
      monitor = [ ", preferred, auto, 1" ];

      plugin = {
        hyprsplit = {
          num_workspaces = 10;
          persistent_workspaces = true;
        };
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          "tap-to-click" = true;
          disable_while_typing = true;
        };
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(88c0d0ff) rgba(81a1c1ff) 45deg";
        "col.inactive_border" = "rgba(3b4252ff)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 8;
          render_power = 2;
          color = "rgba(1a1a1aee)";
        };
      };

      animations = {
        enabled = true;
        bezier = "ease, 0.25, 0.1, 0.25, 1";
        animation = [
          "windows, 1, 4, ease, slide"
          "windowsOut, 1, 4, ease, slide"
          "fade, 1, 4, ease"
          "workspaces, 1, 3, ease, slide"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      # Autostart
      exec-once = [
        "waybar"
        "dunst"
        # Restart waybar on monitor hotplug to avoid duplicate bars
        "socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do case $line in monitoradded*|monitorremoved*) pkill waybar; sleep 0.5; waybar & ;; esac; done"
      ];

      # Key bindings
      "$mod" = "SUPER";

      bind = [
        # Launch
        "$mod, Return, exec, kitty"
        "$mod, Space, exec, rofi -show drun -show-icons"
        "$mod, E, exec, nautilus"
        "$mod, B, exec, firefox"

        # Window management
        "$mod, Q, killactive"
        "$mod SHIFT, Q, exit"
        "$mod, F, fullscreen, 1"
        "$mod SHIFT, F, fullscreen, 0"
        "$mod, V, togglefloating"
        "$mod, P, pseudo"
        "$mod, S, togglesplit"

        # Focus (vim keys)
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Move windows
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"

        # Resize
        "$mod CTRL, H, resizeactive, -40 0"
        "$mod CTRL, L, resizeactive, 40 0"
        "$mod CTRL, K, resizeactive, 0 -40"
        "$mod CTRL, J, resizeactive, 0 40"

        # Workspaces (per-monitor via hyprsplit)
        "$mod, 1, split:workspace, 1"
        "$mod, 2, split:workspace, 2"
        "$mod, 3, split:workspace, 3"
        "$mod, 4, split:workspace, 4"
        "$mod, 5, split:workspace, 5"
        "$mod, 6, split:workspace, 6"
        "$mod, 7, split:workspace, 7"
        "$mod, 8, split:workspace, 8"
        "$mod, 9, split:workspace, 9"
        "$mod, 0, split:workspace, 10"

        # Move window to workspace (per-monitor)
        "$mod SHIFT, 1, split:movetoworkspacesilent, 1"
        "$mod SHIFT, 2, split:movetoworkspacesilent, 2"
        "$mod SHIFT, 3, split:movetoworkspacesilent, 3"
        "$mod SHIFT, 4, split:movetoworkspacesilent, 4"
        "$mod SHIFT, 5, split:movetoworkspacesilent, 5"
        "$mod SHIFT, 6, split:movetoworkspacesilent, 6"
        "$mod SHIFT, 7, split:movetoworkspacesilent, 7"
        "$mod SHIFT, 8, split:movetoworkspacesilent, 8"
        "$mod SHIFT, 9, split:movetoworkspacesilent, 9"
        "$mod SHIFT, 0, split:movetoworkspacesilent, 10"

        # Swap active workspaces between monitors
        "$mod, D, split:swapactiveworkspaces, current +1"

        # Grab rogue windows (useful after unplugging monitors)
        "$mod, G, split:grabroguewindows"

        # Cycle focus between monitors
        "$mod, Tab, focusmonitor, +1"

        # Screenshots (grim + slurp)
        ", Print, exec, grim - | wl-copy"
        "SHIFT, Print, exec, grim -g \"$(slurp)\" - | wl-copy"

        # Relative workspace navigation
        "$mod, Left, split:workspace, e-1"
        "$mod, Right, split:workspace, e+1"

        # Mouse scroll through workspaces
        "$mod, mouse_down, split:workspace, e+1"
        "$mod, mouse_up, split:workspace, e-1"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Audio (wireplumber)
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];
    };

    extraConfig = "";
  };
}
