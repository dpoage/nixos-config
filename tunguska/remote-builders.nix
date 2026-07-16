# Offload builds to oerlikon over ssh-ng. The nix daemon connects as root
# and authenticates with this machine's ssh HOST key — it exists on every
# NixOS host, so no per-machine key provisioning is needed here. oerlikon
# authorizes that public key for its dedicated `nixremote` user (see
# oerlikon/remote-builder.nix).
#
# aarch64/riscv64 on oerlikon run under the same qemu binfmt emulation as
# everywhere else (common/default.nix), so offloading those buys oerlikon's
# CPU and parallelism — not native-arch speed.
{ ... }:

{
  nix.distributedBuilds = true;

  # Let the builder substitute from cache.nixos.org itself instead of
  # funneling every store path through this machine's connection.
  nix.settings.builders-use-substitutes = true;

  nix.buildMachines = [
    {
      hostName = "oerlikon";
      sshUser = "nixremote";
      sshKey = "/etc/ssh/ssh_host_ed25519_key";
      protocol = "ssh-ng";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      maxJobs = 4;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
    }
  ];

  # Pin oerlikon's host key (captured from its
  # /etc/ssh/ssh_host_ed25519_key.pub) so the daemon's non-interactive ssh
  # never stalls on a trust prompt. Resolving the name "oerlikon" requires
  # joining this host to the tailnet or a networking.hosts entry — nc-49s.
  programs.ssh.knownHosts.oerlikon = {
    extraHostNames = [ "100.78.69.7" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0j5yT8k95G5hvtt3MfvnQK7YqnIKRcwhkv4Ogfyc+u";
  };
}
