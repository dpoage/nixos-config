# Wallpaper daemon (swww) + set-wallpaper helper script.
#
# nixpkgs release-25.11 still ships the original `swww`; the rename to
# `awww` only landed post-branch on master. The CLI is identical, so the
# helper works for both — only the binary name differs. We use swww here
# and update when the channel moves.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;

  setWallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [ swww coreutils findutils ];
    text = ''
      # Wallpaper helper. Usage:
      #   set-wallpaper            # random from $WALLPAPER_DIR
      #   set-wallpaper restore    # re-apply last (used at session start)
      #   set-wallpaper <path>     # explicit file

      set -euo pipefail

      WALLPAPER_DIR="''${WALLPAPER_DIR:-${cfg.wallpaperDir}}"
      STATE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/swww/current"

      mkdir -p "$(dirname "$STATE_FILE")"

      # Probe the daemon's socket directly instead of pgrep — avoids a
      # procps scan and a race when two invocations land near-simultaneously.
      if ! swww query >/dev/null 2>&1; then
          swww-daemon >/dev/null 2>&1 &
          for _ in {1..50}; do
              swww query >/dev/null 2>&1 && break
              sleep 0.1
          done
      fi

      pick_random() {
          find "$WALLPAPER_DIR" -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
            | shuf -n 1
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
          echo "set-wallpaper: no valid image found in $WALLPAPER_DIR" >&2
          exit 1
      fi

      # Skip the cross-fade on session-start restore — it just delays the
      # first paint with no visible source to fade from.
      if [[ "$mode" == "restore" ]]; then
          swww img "$target" --transition-type none
      else
          swww img "$target" \
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
    home.packages = [ pkgs.swww setWallpaper ];

    # Hyprland users want the daemon spawned via exec-once; the niri module
    # handles the spawn-sh-at-startup line itself when compositor=niri.
    # For other setups, a systemd user service is a portable fallback.
    systemd.user.services.swww = lib.mkIf (cfg.compositor != "niri") {
      Unit = {
        Description = "swww wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swww}/bin/swww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
