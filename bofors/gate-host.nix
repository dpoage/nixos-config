# bofors runs sar_build's gates on bare metal with the whole machine. A gate
# run is VOID when anything outside it uses more than 4 CPUs in a 10 s window.
{ lib, pkgs, ... }:

{
  powerManagement.cpuFreqGovernor = "performance";

  # An unattended rebuild here VOIDed a gate hold (sar Q32); deploy by hand.
  system.autoUpgrade.enable = lib.mkForce false;

  # lavapipe (software Vulkan) for the Godot testbed legs; the ICD lands in
  # /run/opengl-driver/share/vulkan/icd.d, not testbed.sh's /usr/share default.
  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    jdk21_headless # TLC (tla2tools.jar)
    jq
    unzip
    xvfb-run
  ];

  # The pinned Godot 4.7.2 zip is a generic-linux binary run through nix-ld.
  programs.nix-ld.libraries = with pkgs; [
    libx11
    libxcursor
    libxinerama
    libxrandr
    libxi
    libxrender
    libxext
    libxkbcommon
    fontconfig
    vulkan-loader
    libGL
  ];
}
