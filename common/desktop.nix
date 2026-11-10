# Everything a machine with a screen and a person at it needs: compositor,
# greeter, audio, fonts, graphics, peripherals. Hosts with a display import
# this directly; headless hosts (bofors) leave it out.
{ config, pkgs, ... }:

{
  programs.firefox.enable = true;

  services.printing.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # QMK/Keychron udev rules (allow flashing without root)
  hardware.keyboard.qmk.enable = true;

  # Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  programs.xwayland.enable = true;

  # Display manager
  services.xserver.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # XDG portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  # Keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Audio
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Compositor-agnostic desktop packages. Compositor-specific tools live
  # in profiles/hyprland-stack.nix (hyprlock/hypridle/hyprpicker, etc.).
  environment.systemPackages = with pkgs; [
    brightnessctl
    # Generic wayland utilities — used by both hyprland and niri.
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    wayland-utils
    wlr-randr

    kitty

    # Keyboard (QMK / Keychron)
    qmk
    qmk_hid
    vial
  ];

  # Fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      font-awesome
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.sauce-code-pro
      nerd-fonts.iosevka
      nerd-fonts.ubuntu-mono
      nerd-fonts.roboto-mono
      nerd-fonts.meslo-lg
      nerd-fonts.inconsolata
      nerd-fonts.victor-mono
    ];
  };

  # Wayland environment
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
