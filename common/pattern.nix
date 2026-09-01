{ config, lib, pkgs, ... }:

let
  cfg = config.pattern;
  # Nix daemon and sandbox need a real file at a path outside any home
  # directory: homes are mode 700 (invisible to nixbld sandbox users) and
  # sandbox-mounting a symlink into /run/secrets.d is not reliable, so the
  # decrypted secret is copied here at activation time.
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

      Credentials, both encoded in the repo or recoverable:
        - an ssh key that can read Pattern-Labs/pattern_cli (the flake input
          is git+ssh, so eval itself fails without it), and
        - a netrc with a GitHub token, for the goModules FOD to fetch
          github.com/Pattern-Labs/* under GOPRIVATE. Encrypted at
          secrets/netrc (sops, age recipients in .sops.yaml); decrypted by
          sops-nix via this host's ssh ed25519 key.

      Bootstrap on a host enabling this for the first time (the pattern build
      needs ${daemonNetrc} *before* the first rebuild with this enabled, and
      after a reinstall the new host key must be added to .sops.yaml first):
        sops decrypt --input-type binary secrets/netrc \
          | sudo install -o root -g nixbld -m 0440 /dev/stdin ${daemonNetrc}
      Later rebuilds refresh it from the secret automatically.
    '';
  };

  options.pattern.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = config.myUser.name;
    description = "User who gets ~/.netrc (for bazel and other Pattern tooling outside the sandbox)";
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

      # Daemon-side netrc, decrypted from the repo by sops-nix (keyed to this
      # host's ssh ed25519 key — see .sops.yaml).
      sops.secrets."pattern-netrc" = {
        sopsFile = ../secrets/netrc;
        format = "binary";
      };

      # Pattern dev tooling (bazel et al.) reads ~/.netrc directly; expose the
      # same secret to the primary user.
      sops.secrets."pattern-netrc-user" = {
        sopsFile = ../secrets/netrc;
        format = "binary";
        owner = cfg.primaryUser;
        mode = "0400";
        path = "/home/${cfg.primaryUser}/.netrc";
      };

      # Copy (not symlink) into place for the daemon and sandbox: group nixbld
      # 0440 so FOD builders can read it, no one else can.
      system.activationScripts.nix-netrc = {
        deps = [ "setupSecrets" ];
        text = ''
          install -o root -g nixbld -m 0440 \
            ${config.sops.secrets."pattern-netrc".path} ${daemonNetrc}
        '';
      };

      # Private repo access: netrc-file lets the Nix daemon authenticate HTTPS
      # fetches (flake inputs, go mod download FODs). extra-sandbox-paths makes
      # the netrc available inside build sandboxes for GOPRIVATE module fetching.
      #
      # Gated: a non-optional sandbox path that does not exist is a hard error
      # for *every* build, so this must not be set on a machine without the
      # netrc in place (see bootstrap note in the enable option).
      nix.settings.netrc-file = daemonNetrc;
      nix.settings.extra-sandbox-paths = [ daemonNetrc ];
    })
  ];
}
