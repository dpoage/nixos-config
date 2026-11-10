{ config, lib, ... }:

let
  rice = config.myRice;
  stylix = config.stylix;
  colors = config.lib.stylix.colors.withHashtag;

  # The Stylix waybar target defines @base00..@base0F; the bright half is added here.
  brightDefs = lib.concatMapStringsSep "\n"
    (n: "@define-color ${n} ${colors.${n}};")
    [ "base12" "base13" "base14" "base15" "base16" "base17" ];

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
in
{
  # Our CSS below is the layout; the target contributes the @base00..@base0F defines and a default font.
  stylix.targets.waybar.addCss = false;

  # Only the themed Waybar when `myRice.bar = "waybar"` (the default);
  # other bar choices activate their own module instead.
  programs.waybar = lib.mkIf (rice.bar == "waybar") {
    enable = true;
    settings = {
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
          timezone = "America/Denver";
          format = "${i.clock} {:%F %R}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='${colors.base17}'><b>{}</b></span>";
              days = "<span color='${colors.base05}'><b>{}</b></span>";
              weeks = "<span color='${colors.base15}'>W{}</span>";
              weekdays = "<span color='${colors.base0A}'><b>{}</b></span>";
              today = "<span color='${colors.base06}'><b><u>{}</u></b></span>";
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

    style = ''
      ${brightDefs}

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
          color: @base04;
          box-shadow: none;
          text-shadow: none;
          transition: background-color 150ms ease, color 150ms ease;
      }

      #workspaces button:hover {
          background-color: @base02;
          color: @base05;
      }

      #workspaces button.active {
          background-color: @base17;
          color: @base00;
      }

      #workspaces button.urgent {
          background-color: @base12;
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
          color: @base04;
      }

      #idle_inhibitor.activated {
          color: @base0A;
      }

      #disk {
          color: @base13;
      }

      #temperature {
          color: @base17;
          min-width: 37px;
      }

      #cpu {
          color: @base0E;
          min-width: 45px;
      }

      #memory {
          color: @base16;
      }

      #bluetooth {
          color: @base0D;
      }

      #network {
          color: @base09;
      }

      #backlight {
          color: @base0E;
      }

      #pulseaudio {
          color: @base0A;
      }

      #battery {
          color: @base15;
      }

      #battery.warning {
          color: @base09;
      }

      #clock {
          color: @base14;
          font-weight: bold;
      }

      #disk.warning {
          color: @base09;
      }

      #network.disconnected,
      #pulseaudio.muted,
      #temperature.critical,
      #memory.critical,
      #disk.critical {
          color: @base12;
      }

      @keyframes blink {
          to {
              color: @base01;
          }
      }

      #battery.critical:not(.charging) {
          color: @base12;
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
