{ config, lib, pkgs, extraPkgs, ... }:

let
  # Avoid reading config.users.users here — it creates infinite recursion
  # with nix.settings (nix-daemon.nix evaluates users during nrBuildUsers).
  netrcPath = "/home/${config.pattern.primaryUser}/.netrc";
in
{
  imports = [
    ./kubernetes.nix
  ];

  options.pattern.primaryUser = lib.mkOption {
    type = lib.types.str;
    description = "Username whose ~/.netrc is used for private repo access in Nix sandbox";
  };

  config = {
    environment.systemPackages = [
      extraPkgs.pattern
      pkgs.bazelisk
    ];

    # Private repo access: netrc-file lets the Nix daemon authenticate HTTPS
    # fetches (flake inputs, go mod download FODs). extra-sandbox-paths makes
    # the netrc available inside build sandboxes for GOPRIVATE module fetching.
    nix.settings.netrc-file = netrcPath;
    nix.settings.extra-sandbox-paths = [ netrcPath ];
  };
}
