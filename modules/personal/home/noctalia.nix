# Noctalia desktop shell; active when `myRice.bar = "noctalia"`.
# It owns its config under ~/.config/noctalia, so only the binary is installed.

{ config, lib, pkgs, ... }:

let
  rice = config.myRice;
in
{
  config = lib.mkIf (rice.bar == "noctalia") {
    home.packages = [ pkgs.noctalia ];
  };
}
