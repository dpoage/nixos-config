# Two GitHub Actions runner microVMs, one per CCD: each gets a whole CCD's
# 8 cores / 16 threads and its own L3, so timings stay comparable.
{ lib, pkgs, ... }:

let
  keys = import ./ssh-keys.nix;

  # Each runner VM registers one runner per repo.
  repos = [ "sar_build" ];

  # CPU lists from `lscpu -e`: CCD0 = cores 0-7 (+SMT 16-23), CCD1 = 8-15 (+24-31).
  vms = {
    bofors-ci1 = {
      cpus = "0-7 16-23";
      mac = "02:b0:f0:00:00:01";
    };
    bofors-ci2 = {
      cpus = "8-15 24-31";
      mac = "02:b0:f0:00:00:02";
    };
  };

  tokenDir = "/var/lib/github-runner-tokens";
  workRoot = "/var/lib/github-runner-work";

  guest =
    name: vm:
    { ... }:
    {
      microvm = {
        hypervisor = "qemu";
        vcpu = 16;
        mem = 12 * 1024;
        interfaces = [
          {
            type = "macvtap";
            id = "vm-${name}";
            inherit (vm) mac;
            macvtap = {
              link = "enp4s0";
              mode = "bridge";
            };
          }
        ];
        shares = [
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            proto = "virtiofs";
          }
        ];
        # Root is tmpfs; runner registration, caches and ssh host keys live here.
        volumes = [
          {
            image = "var.img";
            mountPoint = "/var";
            size = 200 * 1024;
          }
        ];
      };

      networking.useNetworkd = true;
      systemd.network.networks."10-lan" = {
        matchConfig.Type = "ether";
        networkConfig.DHCP = "yes";
      };

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "prohibit-password";
        };
        hostKeys = [
          {
            path = "/var/lib/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
      users.users.root.openssh.authorizedKeys.keys = keys;

      # rustup toolchains and `cargo kani setup` download generic-linux binaries.
      programs.nix-ld.enable = true;

      users.groups.github-runner = { };
      users.users.github-runner = {
        isSystemUser = true;
        group = "github-runner";
      };
      systemd.tmpfiles.rules = [
        "d ${tokenDir} 0700 github-runner github-runner -"
      ]
      ++ map (repo: "d ${workRoot}/${repo} 0700 github-runner github-runner -") repos;

      # Registration token (1h, `gh api -X POST repos/dpoage/<repo>/actions/runners/registration-token`)
      # is written by hand to tokenDir/<repo>; registration then persists under /var.
      services.github-runners = lib.genAttrs repos (repo: {
        enable = true;
        url = "https://github.com/dpoage/${repo}";
        name = "${name}-${repo}";
        tokenFile = "${tokenDir}/${repo}";
        replace = true;
        extraLabels = [
          "nixos"
          "bofors"
        ];
        user = "github-runner";
        group = "github-runner";
        workDir = "${workRoot}/${repo}";
        # What sar_build's self-hosted jobs and scripts/ call; the Ubuntu-only
        # testbed job stays on GitHub-hosted runners.
        extraPackages = with pkgs; [
          rustup
          stdenv.cc
          pkg-config
          binutils
          gawk
          gnugrep
          gnused
          findutils
          diffutils
          util-linux
          procps
          file
          which
          curl
          unzip
          xz
          python3
        ];
      });

      system.stateVersion = "26.05";
    };
in
{
  microvm.vms = lib.mapAttrs (name: vm: { config = guest name vm; }) vms;

  # Pin each VM's qemu and virtiofsd to its CCD.
  systemd.services = lib.concatMapAttrs (name: vm: {
    "microvm@${name}".serviceConfig.CPUAffinity = vm.cpus;
    "microvm-virtiofsd@${name}".serviceConfig.CPUAffinity = vm.cpus;
  }) vms;

  networking.networkmanager.unmanaged = [ "interface-name:vm-*" ];

  # VM disk images on btrfs: no copy-on-write (inherited by new files).
  systemd.tmpfiles.rules = [ "h /var/lib/microvms - - - - +C" ];
}
