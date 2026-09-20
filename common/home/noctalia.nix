# Noctalia desktop shell (Quickshell-based), an alternative to Waybar.
#
# Activates only when `myRice.bar = "noctalia"`. Noctalia manages its own
# runtime config/theming under ~/.config/noctalia (settings UI + IPC), so
# this module only puts the `noctalia-shell` binary on PATH; the compositor
# autostart launches it via `myRice.barCommand`.
#
# Pulled from nixpkgs-unstable because noctalia-shell is not yet in the
# pinned stable (25.11) channel.

{ config, lib, pkgs, ... }:

let
  rice = config.myRice;
in
{
  config = lib.mkIf (rice.bar == "noctalia") {
    home.packages = [ pkgs.unstable.noctalia-shell ];
  };
}
