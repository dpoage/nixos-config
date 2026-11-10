# Wallpaper daemon (awww, formerly swww) + set-wallpaper helper script.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;

  setWallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [ awww coreutils findutils ];
    text = ''
      # Wallpaper helper. Usage:
      #   set-wallpaper            # random from $WALLPAPER_DIR, else the theme wallpaper
      #   set-wallpaper restore    # re-apply last (used at session start)
      #   set-wallpaper <path>     # explicit file

      set -euo pipefail

      WALLPAPER_DIR="''${WALLPAPER_DIR:-${cfg.wallpaperDir}}"
      STATE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/awww/current"

      mkdir -p "$(dirname "$STATE_FILE")"

      # Probe the daemon's socket directly instead of pgrep — avoids a
      # procps scan and a race when two invocations land near-simultaneously.
      if ! awww query >/dev/null 2>&1; then
          awww-daemon >/dev/null 2>&1 &
          for _ in {1..50}; do
              awww query >/dev/null 2>&1 && break
              sleep 0.1
          done
      fi

      pick_random() {
          local pick
          pick=$(find "$WALLPAPER_DIR" -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
            2>/dev/null | shuf -n 1 || true)
          echo "''${pick:-${config.stylix.image}}"
      }

      mode="''${1:-random}"
      case "$mode" in
          restore)
              target=""
              if [[ -s "$STATE_FILE" ]]; then
                  target=$(<"$STATE_FILE")
                  [[ -f "$target" ]] || target=""
              fi
              [[ -n "$target" ]] || target="$(pick_random)"
              ;;
          random)
              target="$(pick_random)"
              ;;
          *)
              target="$mode"
              ;;
      esac

      if [[ -z "''${target:-}" || ! -f "$target" ]]; then
          echo "set-wallpaper: no such image: ''${target:-}" >&2
          exit 1
      fi

      # Skip the cross-fade on session-start restore — it just delays the
      # first paint with no visible source to fade from.
      if [[ "$mode" == "restore" ]]; then
          awww img "$target" --transition-type none
      else
          awww img "$target" \
              --transition-type any \
              --transition-fps 60 \
              --transition-duration 1.2
      fi

      echo "$target" > "$STATE_FILE"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.awww setWallpaper ];

    # Hyprland users want the daemon spawned via exec-once; the niri module
    # handles the spawn-sh-at-startup line itself when compositor=niri.
    # For other setups, a systemd user service is a portable fallback.
    systemd.user.services.awww = lib.mkIf (cfg.compositor != "niri") {
      Unit = {
        Description = "awww wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
