# bofors: headless sar_build gate host (Ryzen 9 8945HX, 16c/32t, 32 GB).
{ ... }:

let
  keys = import ./ssh-keys.nix;
in
{
  imports = [ ../modules/core/profiles/workstation.nix ];

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

  myUser = {
    name = "dustin";
    home =
      { ... }:
      {
        imports = [
          ../modules/personal/home/terminal.nix
          ../modules/personal/home/dev.nix
          ../modules/personal/home/rice
        ];
        home.stateVersion = "26.05";
      };
  };
  users.users.dustin.openssh.authorizedKeys.keys = keys;

  system.stateVersion = "26.05";
}
