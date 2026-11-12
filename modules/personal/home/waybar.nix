{ config, lib, pkgs, osConfig, ... }:

let
  rice = config.myRice;
  stylix = config.stylix;

  # Named colors the style sheet uses. Light palettes: most accents are too
  # pale for 4.5:1 text on the islands (base01), so @fg_* are pulled toward the ink.
  colorDefs = { colors, roles, ... }:
    let
      slots = [ "00" "01" "02" "03" "04" "05" "06" "07" "08" "09" "0A" "0B" "0C" "0D" "0E" "0F"
        "10" "11" "12" "13" "14" "15" "16" "17" ];
      define = name: hex: "@define-color ${name} #${hex};\n";
    in
    lib.concatMapStrings (s: define "base${s}" colors."base${s}") slots
    + lib.concatMapStrings (s: define "fg_base${s}" (roles.fg "base${s}")) slots
    + define "dim_base04" (roles.fgDim "base04")
    + define "warning" roles.warning
    # On catppuccin-latte's islands base12 is 3.2:1 and base08 4.46:1, so light takes the normal red.
    + define "critical" roles.danger;

  # Compositor-aware workspace/window modules — waybar exposes distinct module
  # names per compositor, so pick them from myRice.compositor.
  isNiri = rice.compositor == "niri";
  wsModule = if isNiri then "niri/workspaces" else "hyprland/workspaces";
  winModule = if isNiri then "niri/window" else "hyprland/window";

  # Nerd Font codepoints as escapes: literal private-use glyphs get stripped by editors and tools.
  g = cp: builtins.fromJSON ''"\u${cp}"'';
  i = {
    urgent = g "f06a";
    bt = g "f293";
    eye = g "f06e";
    eyeOff = g "f070";
    clock = g "f017";
    cpu = g "f2db";
    mem = g "efc5";
    disk = g "f0a0";
    temp = map g [ "f2cb" "f2c9" "f2c7" ];
    wifi = g "f1eb";
    eth = g "f0e8";
    sun = g "f185";
    vol = map g [ "f026" "f027" "f028" ];
    headphone = g "f025";
    mic = g "f130";
    micOff = g "f131";
    bolt = g "f0e7";
    plug = g "f1e6";
    battery = map g [ "f244" "f243" "f242" "f241" "f240" ];
  };

  workspacesSettings = {
    format = "{icon}";
    format-icons.urgent = i.urgent;
  } // lib.optionalAttrs (!isNiri) {
    on-scroll-up = "hyprctl dispatch workspace e+1";
    on-scroll-down = "hyprctl dispatch workspace e-1";
  };

  # Bar config per palette: the calendar colors its markup.
  barSettings = { colors, roles, ... }: {
    mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      spacing = 0;
      margin-top = 6;
      margin-left = 8;
      margin-right = 8;

      modules-left = [
        wsModule
        "tray"
        "mpris"
      ];

      modules-center = [
        winModule
      ];

      modules-right = [
        "idle_inhibitor"
        "disk#root"
        "temperature"
        "cpu"
        "memory"
        "bluetooth"
        "network"
        "backlight"
        "pulseaudio"
        "battery"
        "clock"
      ];

      ${wsModule} = workspacesSettings;

      ${winModule} = {
        max-length = 60;
      };

      bluetooth = {
        format-on = i.bt;
        format-off = "${i.bt} {status}";
        format-connected = "${i.bt} {device_alias}";
        format-connected-battery = "${i.bt} {device_alias} {device_battery_percentage}%";
        tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
        tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
        tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
      };

      mpris = {
        interval = 15;
        format = "{player_icon} {dynamic}";
        format-paused = "{status_icon} <i>{dynamic}</i>";
        dynamic-order = [ "artist" "title" ];
        player-icons = {
          default = "▶";
          firefox = "▶";
        };
        status-icons = {
          paused = "⏸";
        };
      };

      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = i.eye;
          deactivated = i.eyeOff;
        };
      };

      tray = {
        icon-size = 13;
        spacing = 10;
      };

      clock = {
        interval = 60;
        timezone = osConfig.time.timeZone;
        format = "${i.clock} {:%F %R}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "year";
          mode-mon-col = 3;
          weeks-pos = "right";
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            months = "<span color='#${roles.fg "base17"}'><b>{}</b></span>";
            days = "<span color='#${colors.base05}'><b>{}</b></span>";
            weeks = "<span color='#${roles.fg "base15"}'>W{}</span>";
            weekdays = "<span color='#${roles.fg "base0A"}'><b>{}</b></span>";
            today = "<span color='#${roles.fg "base06"}'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          on-click-right = "mode";
          on-click-forward = "tz_up";
          on-click-backward = "tz_down";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };

      cpu = {
        interval = 3;
        format = "${i.cpu} {usage}%";
        on-click = "kitty htop";
      };

      memory = {
        interval = 3;
        format = "${i.mem} {}%";
        on-click = "kitty htop";
        tooltip-format = "Used: {used:0.1f}G/{total:0.1f}G. Swap: {swapUsed:0.1f}G/{swapTotal:0.1f}G";
        states = {
          critical = 80;
        };
      };

      temperature = {
        interval = 3;
        critical-threshold = 90;
        format-critical = "{icon} {temperatureC}°C";
        format = "{icon} {temperatureC}°C";
        format-icons = i.temp;
      };

      "disk#root" = {
        interval = 60;
        format = "${i.disk} {free}";
        path = "/";
        tooltip = true;
        warning = 80;
        critical = 90;
      };

      network = {
        interval = 60;
        format-ethernet = i.eth;
        format-wifi = "${i.wifi} {essid} {signalStrength}%";
        tooltip-format-ethernet = "{ifname}: {ipaddr}/{cidr}";
        tooltip-format-wifi = "{ifname}: {ipaddr}/{cidr}";
        format-linked = "${i.eth} no IP";
        format-disconnected = "⚠ Disconnected";
      };

      backlight = {
        format = "${i.sun} {percent}%";
        scroll-step = 5;
        on-scroll-up = "brightnessctl set +5%";
        on-scroll-down = "brightnessctl set 5%-";
        tooltip-format = "Brightness: {percent}%";
      };

      pulseaudio = {
        scroll-step = 2;
        format = "{icon} {volume}% {format_source}";
        format-muted = "${builtins.head i.vol} muted {format_source}";
        format-source = "${i.mic} {volume}%";
        format-source-muted = i.micOff;
        format-icons = {
          headphone = i.headphone;
          headset = i.headphone;
          default = i.vol;
        };
        on-click = "pavucontrol";
      };

      battery = {
        interval = 30;
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-charging = "${i.bolt} {capacity}%";
        format-plugged = "${i.plug} {capacity}%";
        format-icons = i.battery;
        tooltip-format = "{timeTo}\n{power}W";
      };
    };
  };
in
{
  # Colors come from the waybar theme slots, fonts from stylix.fonts below.
  stylix.targets.waybar.enable = false;

  # Only the themed Waybar when `myRice.bar = "waybar"` (the default);
  # other bar choices activate their own module instead.
  myTheme.apps = lib.mkIf (rice.bar == "waybar") {
    waybar = {
      render = theme: builtins.toJSON (lib.attrValues (barSettings theme));
      path = "${config.xdg.configHome}/waybar/config";
    };
    # SIGUSR2 reloads both config and style.
    "waybar.css" = {
      render = colorDefs;
      reload = "if ${pkgs.procps}/bin/pgrep -U \"$UID\" waybar >/dev/null; then ${pkgs.procps}/bin/pkill -USR2 -U \"$UID\" waybar; fi";
    };
  };

  programs.waybar = lib.mkIf (rice.bar == "waybar") {
    enable = true;

    style = ''
      @import url("file://${config.myTheme.apps."waybar.css".path}");

      * {
          border: none;
          border-radius: 0;
          font-family: ${stylix.fonts.monospace.name}, Font Awesome;
          font-size: 13px;
          min-height: 0;
      }

      window#waybar {
          background: transparent;
          color: @base05;
      }

      window#waybar.hidden {
          opacity: 0.2;
      }

      .modules-left,
      .modules-center,
      .modules-right {
          background-color: @base01;
          border: 1px solid @base02;
          border-radius: 12px;
          padding: 0 6px;
      }

      window#waybar.empty .modules-center {
          background-color: transparent;
          border-color: transparent;
      }

      tooltip {
          background-color: @base00;
          border: 1px solid @base02;
          border-radius: 8px;
      }

      tooltip label {
          color: @base05;
      }

      #workspaces {
          margin: 0 2px 0 0;
      }

      #workspaces button {
          padding: 0 7px;
          margin: 5px 2px;
          border-radius: 8px;
          background: transparent;
          color: @dim_base04;
          box-shadow: none;
          text-shadow: none;
          transition: background-color 150ms ease, color 150ms ease;
      }

      #workspaces button:hover {
          background-color: @base02;
          color: @base05;
      }

      #workspaces button.active {
          background-color: @fg_base17;
          color: @base00;
      }

      #workspaces button.urgent {
          background-color: @critical;
          color: @base00;
      }

      #window {
          padding: 0 10px;
          color: @base05;
      }

      #mpris,
      #clock,
      #backlight,
      #pulseaudio,
      #bluetooth,
      #network,
      #memory,
      #cpu,
      #temperature,
      #disk,
      #battery,
      #idle_inhibitor,
      #tray {
          padding: 0 9px;
          background: transparent;
          color: @base05;
      }

      #mpris {
          color: @base05;
      }

      #idle_inhibitor {
          color: @dim_base04;
      }

      #idle_inhibitor.activated {
          color: @fg_base0A;
      }

      #disk {
          color: @fg_base13;
      }

      #temperature {
          color: @fg_base17;
          min-width: 37px;
      }

      #cpu {
          color: @fg_base0E;
          min-width: 45px;
      }

      #memory {
          color: @fg_base16;
      }

      #bluetooth {
          color: @fg_base0D;
      }

      #network {
          color: @fg_base09;
      }

      #backlight {
          color: @fg_base0E;
      }

      #pulseaudio {
          color: @fg_base0A;
      }

      #battery {
          color: @fg_base15;
      }

      #battery.warning {
          color: @warning;
      }

      #clock {
          color: @fg_base14;
          font-weight: bold;
      }

      #disk.warning {
          color: @warning;
      }

      #network.disconnected,
      #pulseaudio.muted,
      #temperature.critical,
      #memory.critical,
      #disk.critical {
          color: @critical;
      }

      @keyframes blink {
          to {
              color: @base01;
          }
      }

      #battery.critical:not(.charging) {
          color: @critical;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: steps(12);
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      #tray > .passive {
          -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
          -gtk-icon-effect: highlight;
      }
    '';
  };
}
