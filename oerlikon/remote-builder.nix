# Accept remote nix builds from tunguska. Its daemon sshes in as
# `nixremote`, authenticating with tunguska's ssh HOST key. A dedicated
# user (rather than dpoage) limits what a root process on the client can
# reach on this machine to exactly this account.
{ ... }:

{
  users.users.nixremote = {
    isNormalUser = true;
    description = "Remote nix build user (tunguska)";
    openssh.authorizedKeys.keys = [
      # tunguska's /etc/ssh/ssh_host_ed25519_key.pub goes here. It was
      # unreachable when this was wired; until the key lands, remote
      # builds fail at ssh auth. Tracked in nc-49s.
    ];
  };

  # Remote building copies unsigned store paths in both directions; the
  # ssh user must be trusted by the daemon. Merges with root/@wheel from
  # common/default.nix.
  nix.settings.trusted-users = [ "nixremote" ];
}
