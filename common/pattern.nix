{ config, lib, pkgs, ... }:

let
  userNetrc = "/home/${config.pattern.primaryUser}/.netrc";
  # Nix daemon and sandbox need a path outside the user's home directory,
  # which is typically mode 700 and inaccessible to nixbld users.
  daemonNetrc = "/etc/nix/netrc";
in
{
  imports = [
    ./kubernetes.nix
  ];

  options.pattern.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = config.myUser.name;
    description = "Username whose ~/.netrc is used for private repo access in Nix sandbox";
  };

  config = {
    environment.systemPackages = [
      pkgs.gcx
      pkgs.pattern
    ];

    # Tools pattern shells out to hardcode /bin/bash, which doesn't exist on
    # NixOS (only /bin/sh). Provide it as a symlink; bashInteractive matches
    # what /bin/sh already points at, so this adds nothing to the closure.
    systemd.tmpfiles.rules = [
      "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    ];

    # Copy the user's .netrc to a daemon-accessible location so nixbld users
    # can reach it (user home dirs are typically mode 700).
    system.activationScripts.nix-netrc = ''
      src="${userNetrc}"
      dst="${daemonNetrc}"
      if [ -f "$src" ]; then
        cp "$src" "$dst"
        chmod 600 "$dst"
      fi
    '';

    # Private repo access: netrc-file lets the Nix daemon authenticate HTTPS
    # fetches (flake inputs, go mod download FODs). extra-sandbox-paths makes
    # the netrc available inside build sandboxes for GOPRIVATE module fetching.
    nix.settings.netrc-file = daemonNetrc;
    nix.settings.extra-sandbox-paths = [ daemonNetrc ];
  };
}
