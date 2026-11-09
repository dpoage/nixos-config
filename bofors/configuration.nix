# bofors: headless CI host (Ryzen 9 8945HX, 16c/32t, 32 GB). The host only
# runs the CI microVMs in ./ci-vms.nix; no desktop, nothing interactive.
{ lib, ... }:

let
  keys = import ./ssh-keys.nix;
in
{
  imports = [ ../common/profiles/workstation.nix ];

  networking.hostName = "bofors";

  # Key-only sshd. Root takes the same keys so deploys can run
  # `nixos-rebuild switch --flake .#bofors --target-host root@bofors`.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.root.openssh.authorizedKeys.keys = keys;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # No checkout lives on this box, so the daily upgrade reads the public repo.
  system.autoUpgrade.flake = lib.mkForce "github:dpoage/nixos-config#bofors";

  myUser = {
    name = "dustin";
    home =
      { ... }:
      {
        imports = [
          ../common/home/terminal.nix
          ../common/home/dev.nix
          ../common/home/rice
        ];
        home.stateVersion = "26.05";
      };
  };
  users.users.dustin.openssh.authorizedKeys.keys = keys;

  system.stateVersion = "26.05";
}
