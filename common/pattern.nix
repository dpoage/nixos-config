{ config, lib, pkgs, ... }:

let
  normalUsers = builtins.filter
    (u: u.isNormalUser)
    (builtins.attrValues config.users.users);
  primaryUser = builtins.head normalUsers;
in
{
  imports = [
    ./kubernetes.nix
  ];

  assertions = [{
    assertion = builtins.length normalUsers > 0;
    message = "pattern.nix: no normal users found; cannot determine netrc path for Nix sandbox";
  }];

  environment.systemPackages = with pkgs; [
    pattern
    bazelisk
  ];

  # Private Go modules (github.com/Pattern-Labs) need ~/.netrc in the sandbox.
  nix.settings.extra-sandbox-paths = [
    "${primaryUser.home}/.netrc"
  ];
}
