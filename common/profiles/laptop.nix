# Laptop hardware profile: power management, touchpad, thermal,
# brightness, lid switch behavior. Import on any portable host.

{ config, lib, pkgs, ... }:

{
  # Power management. NixOS picks one of power-profiles-daemon or tlp;
  # we explicitly disable PPD so tlp can drive everything.
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
    };
  };
  services.thermald.enable = true;

  # Touchpad + general input
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      clickMethod = "clickfinger";
      disableWhileTyping = true;
    };
  };

  # Brightness control utility (also referenced by compositor brightness binds).
  environment.systemPackages = with pkgs; [
    brightnessctl
    acpi
    powertop
    lm_sensors
  ];
}
