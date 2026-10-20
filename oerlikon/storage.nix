# oerlikon has a second NVMe (1.7T, unused by the original install) that we
# dedicate to heavy, rebuildable state so the ~1T root disk stops filling up:
#   - rootless podman image/layer/volume storage
#   - bazel's output base (redirected via ~/.bazelrc in ./configuration.nix)
{ config, ... }:

let
  innodiskNoD3 = config.boot.kernelPackages.callPackage (
    { stdenv, kernel, kernelModuleMakeFlags }:
    stdenv.mkDerivation {
      pname = "innodisk-no-d3";
      version = "1";
      src = ./innodisk-no-d3;
      nativeBuildInputs = kernel.moduleBuildDependencies;
      makeFlags = kernelModuleMakeFlags ++ [
        "-C"
        "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "M=$(PWD)"
      ];
      buildFlags = [ "modules" ];
      installFlags = [ "INSTALL_MOD_PATH=$(out)" ];
      installTargets = [ "modules_install" ];
    }
  ) { };
in
{
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/e178627b-95a4-41f5-b029-eded5716398c";
    fsType = "ext4";
    # nofail: a dead data disk should not drop boot into emergency mode.
    options = [ "nofail" "noatime" ];
  };

  # The Innodisk 3TE6 never returns from D3cold or D3hot after s2idle; the
  # controller is then dead until a power cycle. Keep it in D0 instead.
  boot.extraModulePackages = [ innodiskNoD3 ];
  boot.kernelModules = [ "innodisk_no_d3" ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1bc0", ATTR{device}=="0x1002", ATTR{d3cold_allowed}="0"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:06.0", ATTR{d3cold_allowed}="0"
  '';

  # Rootless podman storage on the big disk instead of ~/.local/share/containers.
  virtualisation.containers.storage.settings.storage.rootless_storage_path =
    "/data/containers/$USER";

  # User-writable home for relocated caches (bazel output base, etc.).
  systemd.tmpfiles.rules = [
    "d /data/cache 0755 ${config.myUser.name} users -"
  ];

  # The container store is created by a unit rather than tmpfiles for two
  # reasons:
  #   - /data's root is owned by the user, so a root-owned /data/containers
  #     beneath it is an "unsafe path transition" and systemd-tmpfiles refuses
  #     to create anything inside it.
  #   - Gated on /data being mounted: with nofail, an unmounted /data leaves
  #     only the root-owned mount point, podman's mkdir fails loudly, and
  #     images never land on the root fs.
  systemd.services.podman-data-store = {
    description = "Create rootless podman storage on /data";
    wantedBy = [ "multi-user.target" ];
    after = [ "data.mount" ];
    unitConfig = {
      RequiresMountsFor = [ "/data" ];
      ConditionPathIsMountPoint = "/data";
    };
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -o ${config.myUser.name} -g users -m 0755 /data/containers
      install -d -o ${config.myUser.name} -g users -m 0700 /data/containers/${config.myUser.name}
    '';
  };
}
