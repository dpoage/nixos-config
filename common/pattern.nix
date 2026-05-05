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

  # Private repo access: netrc-file lets the Nix daemon authenticate HTTPS
  # fetches (flake inputs, go mod download FODs). extra-sandbox-paths makes
  # the netrc available inside build sandboxes for GOPRIVATE module fetching.
  nix.settings.netrc-file = "${primaryUser.home}/.netrc";
  nix.settings.extra-sandbox-paths = [
    "${primaryUser.home}/.netrc"
  ];
}
