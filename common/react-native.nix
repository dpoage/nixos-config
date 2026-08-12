# React Native (Android) toolchain for the copilot app in the_cloud.
# Versions below mirror copilot/android/build.gradle — keep them in sync:
#   buildToolsVersion 36.0.0, compileSdk 36, ndkVersion 27.1.12297006,
#   Gradle 8.13 wrapper, AGP 8.6 (needs JDK 17).
# Node/TypeScript/yarn live in home/dev.nix; this module is only the
# Android side, so it's imported from profiles/work.nix rather than
# common/default.nix (the SDK closure is multi-GB).

{ config, pkgs, ... }:

let
  buildToolsVersion = "36.0.0";

  androidComposition = pkgs.androidenv.composeAndroidPackages {
    buildToolsVersions = [ buildToolsVersion ];
    platformVersions = [ "36" ];
    includeNDK = true;
    ndkVersions = [ "27.1.12297006" ];
    # AGP 8.6 defaults to CMake 3.22.1 for externalNativeBuild (nitro
    # modules, mmkv, screens); react-native core pins 3.30.5 via
    # CMAKE_VERSION when built from source. Ship both so AGP never tries
    # to sdkmanager-install into the read-only store.
    cmakeVersions = [ "3.22.1" "3.30.5" ];
    # Emulator + x86_64 image for `yarn start:emulator` on this machine;
    # physical devices are arm64 but only need the APK, not an image.
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ "x86_64" ];
  };
  androidSdk = androidComposition.androidsdk;
  sdkRoot = "${androidSdk}/libexec/android-sdk";
in
{
  nixpkgs.config.android_sdk.accept_license = true;

  # SDK on PATH (adb, emulator, avdmanager, sdkmanager come from the SDK
  # itself — deliberately NOT programs.adb, which would add a second,
  # older adb from pkgs.android-tools and cause client/server skew).
  environment.systemPackages = [ androidSdk ];

  # JDK 17: required by AGP 8.6 and satisfies the RN toolchain spec, so
  # Gradle's foojay resolver uses it instead of downloading a JDK.
  programs.java = {
    enable = true;
    package = pkgs.jdk17;
  };

  environment.variables = {
    ANDROID_HOME = sdkRoot;
    ANDROID_SDK_ROOT = sdkRoot; # legacy name; RN scripts still read it
    # programs.java only exports JAVA_HOME via shell init; pin it here so
    # non-shell launchers (IDEs, CI scripts) see it as well.
    JAVA_HOME = "${pkgs.jdk17.home}";
    # AGP downloads a dynamically-linked aapt2 from Maven that can't run
    # on NixOS; point it at the SDK's build-tools copy instead.
    GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${sdkRoot}/build-tools/${buildToolsVersion}/aapt2";
  };

  # React Native DevTools (`npx react-native start` debugger) is a prebuilt
  # Electron app fetched via dotslash into ~/.cache/dotslash; it can't be
  # patchelf'd ahead of time, so run it through nix-ld (enabled in bazel.nix)
  # with the Chromium/Electron runtime closure. List = exact `not found` set
  # from ldd on the binary plus libglvnd (libGL/libEGL dispatch — dlopened at
  # runtime, so absent from ldd; vendor driver comes from /run/opengl-driver
  # via hardware.graphics). Transitive deps resolve via each lib's rpath.
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libgbm
    libglvnd
    libxkbcommon
    nspr
    nss
    pango
    systemd # libudev
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
  ];

  # adb device access is handled by systemd's built-in uaccess rules for
  # seat-local users (nixpkgs removed android-udev-rules in favor of them).
  # /dev/kvm for the hardware-accelerated emulator still needs the group.
  myUser.extraGroups = [ "kvm" ];
}
