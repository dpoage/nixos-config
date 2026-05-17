# Desktop/tower profile: AC-only power assumptions, more aggressive
# build parallelism. Stub for now — fill in as the first workstation
# host gets added.

{ config, lib, pkgs, ... }:

{
  # Make sure no laptop power-management daemons sneak in via defaults.
  services.tlp.enable = lib.mkForce false;
  services.thermald.enable = lib.mkDefault false;
  services.power-profiles-daemon.enable = lib.mkDefault false;

  # Performance defaults: more build jobs (towers usually have more
  # cores and aren't battery-bound).
  nix.settings.max-jobs = lib.mkDefault "auto";
  nix.settings.cores = lib.mkDefault 0; # 0 = all cores
}
