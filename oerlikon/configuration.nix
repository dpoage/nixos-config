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

        # Bazel's output base defaults to ~/.cache/bazel and grows into the
        # hundreds of GB; keep it on the big /data SSD (see ./storage.nix).
        # Wrappers that pass their own --output_user_root are unaffected.
        home.file.".bazelrc".text = ''
          startup --output_user_root=/data/cache/bazel
        '';
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
