# Host stub for checks.patternlabs-example: a non-dpoage user, no personal layer.
{ ... }:

{
  networking.hostName = "example-work";
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  patternlabs.cli = {
    enable = true;
    netrcFile = ../secrets/netrc;
  };
  patternlabs.compliance.rootPasswordFile = ../secrets/root-password;

  myUser = {
    name = "alice";
    home.home.stateVersion = "26.05";
  };

  system.stateVersion = "26.05";
}
