{ config, lib, pkgs, ... }:

let
  # Autostart for the selected bar. Only waybar needs the monitor-hotplug
  # restart shim; quickshell-based bars (noctalia, custom) handle hotplug
  # internally. `barCommand` is null when `myRice.bar = "none"`.
  barExec =
    lib.optional (config.myRice.barCommand != null) config.myRice.barCommand
    ++ lib.optional (config.myRice.bar == "waybar")
      "socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do case $line in monitoradded*|monitorremoved*) pkill waybar; sleep 0.5; waybar & ;; esac; done";
in
{
  # Colors come from the hyprland theme slot's $theme_* variables, which
  # hyprlock (lock.nix) sources too.
  stylix.targets.hyprland.enable = false;
  stylix.targets.dunst.enable = false;
  stylix.targets.hyprpaper.enable = false;

  myTheme.apps = {
    hyprland = {
      render = { colors, roles, ... }:
        lib.concatMapStrings (s: "$theme_base${s} = ${colors."base${s}"}\n") [
          "00" "01" "02" "03" "04" "05" "06" "07" "08" "09" "0A" "0B" "0C" "0D" "0E" "0F"
          "10" "11" "12" "13" "14" "15" "16" "17"
        ]
        # base00 on light palettes is a cream glow, not a shadow; use the (dark) text color there.
        + "$theme_shadow = ${if roles.light then "rgba(${colors.base05}66)" else "rgba(${colors.base00}99)"}\n";
      reload = ''
        shopt -s nullglob
        for dir in "$XDG_RUNTIME_DIR"/hypr/*/; do
          [ -S "$dir.socket.sock" ] || continue
          HYPRLAND_INSTANCE_SIGNATURE=$(basename "$dir") ${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl reload
        done
      '';
    };
    # Rofi's default theme (as Stylix's rofi target writes it) reads these
    # variables; the keybind imports them over it with -theme-str.
    rofi.render = { colors, ... }:
      let
        rgb = s: "rgba ( ${colors."${s}-rgb-r"}, ${colors."${s}-rgb-g"}, ${colors."${s}-rgb-b"}, 100 % )";
        vars = {
          background = rgb "base00"; lightbg = rgb "base01"; red = rgb "base08"; blue = rgb "base0D";
          lightfg = rgb "base06"; foreground = rgb "base05"; background-color = rgb "base00";
          base-text = rgb "base05"; normal-text = rgb "base05"; active-text = rgb "base0D";
          urgent-text = rgb "base08"; selected-normal-text = rgb "base01";
          selected-active-text = rgb "base00"; selected-urgent-text = rgb "base00";
          alternate-normal-text = rgb "base05"; alternate-active-text = rgb "base0D";
          alternate-urgent-text = rgb "base08";
        };
      in
      "* {\n" + lib.concatStrings (lib.mapAttrsToList (k: v: "  ${k}: ${v};\n") vars) + "}\n";
    # dunst reads drop-ins after dunstrc.
    dunst = lib.mkIf config.services.dunst.enable {
      render = { colors, ... }: with colors.withHashtag; ''
        [global]
        separator_color = "${base02}"
        icon_theme = "${if colors.variant == "light" then config.stylix.icons.light else config.stylix.icons.dark}"
        ${lib.concatMapStrings ({ u, frame }: ''
          [urgency_${u}]
          background = "${base01}ff"
          foreground = "${base05}"
          frame_color = "${frame}"
          highlight = "${frame}"
        '') [ { u = "low"; frame = base03; } { u = "normal"; frame = base0D; } { u = "critical"; frame = base08; } ]}
      '';
      path = "${config.xdg.configHome}/dunst/dunstrc.d/50-theme.conf";
      reload = "if ${pkgs.procps}/bin/pgrep -U \"$UID\" dunst >/dev/null; then ${config.services.dunst.package}/bin/dunstctl reload; fi";
    };
    wallpaper = lib.mkIf config.services.hyprpaper.enable {
      render = theme: theme.wallpaper;
      reload = ''
        if ${pkgs.procps}/bin/pgrep -U "$UID" hyprpaper >/dev/null; then
          shopt -s nullglob
          for dir in "$XDG_RUNTIME_DIR"/hypr/*/; do
            HYPRLAND_INSTANCE_SIGNATURE=$(basename "$dir") ${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl \
              hyprpaper wallpaper ",$(readlink -f "$THEME_FILE")"
          done
        fi
      '';
    };
  };

  # With myRice, awww owns the wallpaper.
  services.hyprpaper = lib.mkIf (!config.myRice.enable) {
    enable = true;
    settings = {
      wallpaper = [ { monitor = ""; path = config.myTheme.apps.wallpaper.path; } ];
      splash = false;
    };
  };

  # Launcher and notifier. dunst runs only without the myRice bundle, whose
  # mako owns notifications: one daemon per host, never both.
  programs.rofi.enable = true;
  services.dunst = {
    enable = !config.myRice.enable;
    settings.global = {
      font = "${config.stylix.fonts.sansSerif.name} ${toString config.stylix.fonts.sizes.popups}";
      enable_recursive_icon_lookup = true;
    };
  };
  # HM's dunst unit is only dbus-activated; start it with the session, as
  # the exec-once it replaces did.
  systemd.user.services = lib.mkIf config.services.dunst.enable {
    dunst.Install.WantedBy = [ config.wayland.systemd.target ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    # Settings below are hyprlang-shaped; stay on it until a Lua port.
    configType = "hyprlang";

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

      source = [ config.myTheme.apps.hyprland.path ];

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        layout = "dwindle";
        "col.active_border" = "rgb($theme_base0D)";
        "col.inactive_border" = "rgb($theme_base03)";
      };

      group = {
        "col.border_inactive" = "rgb($theme_base03)";
        "col.border_active" = "rgb($theme_base0D)";
        "col.border_locked_active" = "rgb($theme_base0C)";
        groupbar = {
          text_color = "rgb($theme_base05)";
          "col.active" = "rgb($theme_base0D)";
          "col.inactive" = "rgb($theme_base03)";
        };
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
          color = "$theme_shadow";
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
        preserve_split = true;
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        background_color = "rgb($theme_base00)";
      };

      # Autostart
      exec-once = barExec;

      # Key bindings
      "$mod" = "SUPER";

      bind = [
        # Launch
        "$mod, Return, exec, kitty"
        "$mod, Space, exec, rofi -show drun -show-icons -theme-str '@import \"${config.myTheme.apps.rofi.path}\"'"
        "$mod, E, exec, nautilus"
        "$mod, B, exec, firefox"

        # Session lock (SUPER+L is vim-directional focus; direct exec so
        # the bind still locks even if hypridle is down — see lock.nix)
        "$mod, Escape, exec, pidof hyprlock || hyprlock"

        # Window management
        "$mod, Q, killactive"
        "$mod SHIFT, Q, exit"
        "$mod, F, fullscreen, 1"
        "$mod SHIFT, F, fullscreen, 0"
        "$mod, V, togglefloating"
        "$mod, P, pseudo"
        "$mod, S, layoutmsg, togglesplit"

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
