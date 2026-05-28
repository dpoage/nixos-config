{ config, pkgs, ... }:

{
  imports = [
    ../common/profiles/laptop.nix
    ../common/profiles/work.nix
    # oerlikon runs hyprland only; switch to niri-stack alongside myRice
    # when you migrate this host.
    ../common/profiles/hyprland-stack.nix
  ];

  networking.hostName = "oerlikon";

  myUser = {
    name = "dpoage";
    fullName = "Dustin";
    home =
      { ... }:
      {
        imports = [
          ../common/home
          ./monitors.nix
        ];
        # No rice opt-in yet — oerlikon stays on hyprland + catppuccin
        # defaults. Flip these to migrate the work laptop to gruvbox+niri:
        #
        #   myRice = {
        #     enable = true;
        #     palette = "gruvbox";
        #     compositor = "niri";
        #   };
      };
  };

  system.stateVersion = "25.11";
}
