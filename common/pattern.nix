{ config, lib, pkgs, ... }:

let
  cfg = config.pattern;
  userNetrc = "/home/${cfg.primaryUser}/.netrc";
  # Nix daemon and sandbox need a path outside the user's home directory,
  # which is typically mode 700 and inaccessible to nixbld users.
  daemonNetrc = "/etc/nix/netrc";
in
{
  imports = [
    ./kubernetes.nix
  ];

  options.pattern.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Install the Pattern Labs CLI and wire netrc-based private repo access.

      Needs two credentials that do not survive a reinstall:
        - an ssh key that can read Pattern-Labs/pattern_cli (the flake input
          is git+ssh, so eval itself fails without it), and
        - ~/.netrc with a GitHub token, for the goModules FOD to fetch
          github.com/Pattern-Labs/* under GOPRIVATE.

      Off since the 2026-08-31 LUKS reinstall wiped /home. Flip to true once
      ~/.netrc is back and `sudo install -m600 ~/.netrc /etc/nix/netrc` has
      run — the activation script below only copies it on *later* rebuilds,
      after the pattern build has already needed it.
    '';
  };

  options.pattern.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = config.myUser.name;
    description = "Username whose ~/.netrc is used for private repo access in Nix sandbox";
  };

  config = lib.mkMerge [
    {
      environment.systemPackages = [
        pkgs.gcx
      ];

      # Tools pattern shells out to hardcode /bin/bash, which doesn't exist on
      # NixOS (only /bin/sh). Provide it as a symlink; bashInteractive matches
      # what /bin/sh already points at, so this adds nothing to the closure.
      systemd.tmpfiles.rules = [
        "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
      ];
    }

    (lib.mkIf cfg.enable {
      environment.systemPackages = [ pkgs.pattern ];

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
      #
      # Gated: a non-optional sandbox path that does not exist is a hard error
      # for *every* build, so this must not be set on a machine without the
      # netrc in place.
      nix.settings.netrc-file = daemonNetrc;
      nix.settings.extra-sandbox-paths = [ daemonNetrc ];
    })
  ];
}
