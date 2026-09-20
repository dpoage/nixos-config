# Custom Quickshell bar/shell, an alternative to Waybar.
#
# Activates only when `myRice.bar = "quickshell"`. Installs the Quickshell
# runtime and symlinks the host-provided config directory
# (`myRice.quickshellConfig`, containing a `shell.qml`) to
# ~/.config/quickshell, which the `quickshell` binary reads by default.
# The compositor autostart launches it via `myRice.barCommand`.

{ config, lib, pkgs, ... }:

let
  rice = config.myRice;
  active = rice.bar == "quickshell";
in
{
  config = lib.mkIf active (lib.mkMerge [
    {
      assertions = [
        {
          assertion = rice.quickshellConfig != null;
          message = ''
            myRice.bar = "quickshell" requires myRice.quickshellConfig to
            point at a Quickshell config directory (containing shell.qml).
          '';
        }
      ];

      home.packages = [ pkgs.quickshell ];
    }

    # Guarded separately so a null config surfaces the assertion above
    # instead of a raw type error on the file source.
    (lib.mkIf (rice.quickshellConfig != null) {
      xdg.configFile."quickshell".source = rice.quickshellConfig;
    })
  ]);
}
