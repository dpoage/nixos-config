# shilka: ThinkPad X1 Carbon Gen 11 (i7-1365U, Iris Xe, 32 GB). No dGPU.
{ lib, pkgs, ... }:

{
  imports = [
    ../modules/core/profiles/laptop.nix
    ../modules/personal/profiles/personal.nix
    ../modules/core/profiles/niri-stack.nix
  ];

  networking.hostName = "shilka";

  programs.niri.enable = true;
  services.greetd.settings.default_session.command = lib.mkForce
    "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";

  myTheme.palette = "gruvbox-dark";

  myUser = {
    name = "dustin";
    fullName = "dustin";
    home = { ... }: {
      imports = [ ../modules/personal/home ];
      myRice = {
        enable = true;
        compositor = "niri";
      };
    };
  };
  # personal.nix makes sshd key-only; keep tunguska's access declarative.
  users.users.dustin.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM2IIH+9CmseykoWBj3lAv69mQ7gSJ/NH0mCMEOtl8rd dustin@tunguska"
  ];

  system.stateVersion = "26.05";
}
