{ config, lib, ... }:

let
  rice = config.myRice;
  c = rice.colors;
  named = import ./rice/named.nix c;

  # Waybar CSS @define-color block, generated from the shared semantic map so
  # the bar re-themes with the active palette.
  colorDefs = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: hex: "@define-color ${name} #${hex};") named);

  # Compositor-aware workspace/window modules — waybar exposes distinct module
  # names per compositor, so pick them from myRice.compositor.
  isNiri = rice.compositor == "niri";
  wsModule = if isNiri then "niri/workspaces" else "hyprland/workspaces";
  winModule = if isNiri then "niri/window" else "hyprland/window";

  workspacesSettings = {
    format = "{icon}";
    format-icons.urgent = "";
  } // lib.optionalAttrs (!isNiri) {
    on-scroll-up = "hyprctl dispatch workspace e+1";
    on-scroll-down = "hyprctl dispatch workspace e-1";
  };
in
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 1;

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
          format-on = "bt ";
          format-off = "bt ({status}) ";
          format-connected = "{device_alias} ";
          format-connected-battery = "{device_alias} [{device_battery_percentage}%] ";
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
            activated = "";
            deactivated = "";
          };
        };

        tray = {
          icon-size = 13;
          spacing = 10;
        };

        clock = {
          interval = 60;
          timezone = "America/Denver";
          format = "{:%F %R }";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='#${named.mauve}'><b>{}</b></span>";
              days = "<span color='#${named.text}'><b>{}</b></span>";
              weeks = "<span color='#${named.teal}'>W{}</span>";
              weekdays = "<span color='#${named.yellow}'><b>{}</b></span>";
              today = "<span color='#${named.rosewater}'><b><u>{}</u></b></span>";
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
          format = "{usage}% ";
          on-click = "kitty htop";
        };

        memory = {
          interval = 3;
          format = "{}% ";
          on-click = "kitty htop";
          tooltip-format = "Used: {used:0.1f}G/{total:0.1f}G. Swap: {swapUsed:0.1f}G/{swapTotal:0.1f}G";
          states = {
            critical = 80;
          };
        };

        temperature = {
          interval = 3;
          critical-threshold = 90;
          format-critical = "{temperatureC}°C {icon}";
          format = "{temperatureC}°C {icon}";
          format-icons = [ "" "" "" ];
        };

        "disk#root" = {
          interval = 60;
          format = "/ {free} ";
          path = "/";
          tooltip = true;
          warning = 80;
          critical = 90;
        };

        network = {
          interval = 60;
          format-ethernet = "eth ";
          format-wifi = "{essid} ({signalStrength}%) ";
          tooltip-format-ethernet = "{ifname}: {ipaddr}/{cidr} ";
          tooltip-format-wifi = "{ifname}: {ipaddr}/{cidr} ";
          format-linked = "(No IP) ";
          format-disconnected = "Disconnected ⚠";
        };

        backlight = {
          format = "{percent}% {icon}";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
          scroll-step = 5;
          on-scroll-up = "brightnessctl set +5%";
          on-scroll-down = "brightnessctl set 5%-";
          tooltip-format = "Brightness: {percent}%";
        };

        pulseaudio = {
          scroll-step = 2;
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = "{volume}% ";
          format-source-muted = "";
          format-icons = {
            headphone = " ";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };

        battery = {
          interval = 30;
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-icons = [ "" "" "" "" "" ];
          tooltip-format = "{timeTo}\n{power}W";
        };
      };
    };

    style = ''
      ${colorDefs}

      * {
          border: none;
          border-radius: 1px;
          font-family: JetBrainsMono Nerd Font, Font Awesome;
          font-size: 13px;
          min-height: 0;
      }

      window#waybar {
          background-color: @mantle;
          color: @text;
      }

      window#waybar.hidden {
          opacity: 0.2;
      }

      tooltip {
          background-color: @base;
          border: 1px solid @surface1;
      }

      tooltip label {
          color: @text;
      }

      button {
          box-shadow: inset 0 -3px transparent;
          border: none;
          border-radius: 1px;
      }

      button:hover {
          background: inherit;
          box-shadow: inset 0 -3px @text;
      }

      #workspaces button {
          padding: 0 0;
          background-color: @mantle;
          color: @text;
      }

      #workspaces button:hover {
          box-shadow: inherit;
          text-shadow: inherit;
          background-image: linear-gradient(0deg, @surface1, @mantle);
      }

      #workspaces button.active {
          background-image: linear-gradient(0deg, @mauve, @surface1);
          box-shadow: inset 0 -3px @text;
      }

      #workspaces button.urgent {
          background-image: linear-gradient(0deg, @red, @mantle);
      }

      #mode {
          background-color: @base;
          box-shadow: inset 0 -2px @text;
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
          padding: 0 10px;
          margin: 5px 1px;
          color: @text;
      }

      #window,
      #workspaces {
          margin: 0 4px;
      }

      .modules-left > widget:first-child > #workspaces {
          margin-left: 0;
      }

      .modules-right > widget:last-child > #workspaces {
          margin-right: 0;
      }

      #clock {
          background-color: @green;
          color: @mantle;
      }

      @keyframes blink {
          to {
              background-color: @mantle;
              color: @text;
          }
      }

      label:focus {
          background-color: @mantle;
      }

      #cpu {
          background-color: @mauve;
          color: @mantle;
          min-width: 45px;
      }

      #memory {
          background-color: @red;
          color: @mantle;
      }

      #disk {
          background-color: @flamingo;
          color: @mantle;
      }

      #network {
          background-color: @peach;
          color: @mantle;
      }

      #network.disconnected {
          background-color: @red;
          color: @mantle;
      }

      #bluetooth {
          background-color: @maroon;
          color: @mantle;
          min-width: 40px;
      }

      #backlight {
          background-color: @lavender;
          color: @mantle;
      }

      #pulseaudio {
          background-color: @yellow;
          color: @mantle;
      }

      #pulseaudio.muted {
          background-color: @red;
          color: @mantle;
      }

      #temperature {
          background-color: @pink;
          color: @mantle;
          min-width: 37px;
      }

      #temperature.critical {
          background-color: @red;
          color: @mantle;
          min-width: 37px;
      }

      #battery {
          background-color: @sky;
          color: @mantle;
      }

      #battery.warning {
          background-color: @peach;
          color: @mantle;
      }

      #battery.critical:not(.charging) {
          background-color: @red;
          color: @mantle;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: steps(12);
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      #mpris {
          background-color: @base;
          color: @text;
      }

      #tray {
          background-color: @overlay0;
          color: @text;
      }

      #tray > .passive {
          -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
          -gtk-icon-effect: highlight;
          background-color: @mantle;
      }

      #idle_inhibitor {
          background-color: @base;
          color: @text;
          font-family: Inter;
      }

      #idle_inhibitor.activated {
          background-color: @text;
          color: @base;
      }
    '';
  };
}
