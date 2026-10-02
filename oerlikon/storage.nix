# oerlikon has a second NVMe (1.7T, unused by the original install) that we
# dedicate to heavy, rebuildable state so the ~1T root disk stops filling up:
#   - rootless podman image/layer/volume storage
#   - bazel's output base (redirected via ~/.bazelrc in ./configuration.nix)
{ config, ... }:

{
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/e178627b-95a4-41f5-b029-eded5716398c";
    fsType = "ext4";
    # nofail: a dead data disk should not drop boot into emergency mode.
    options = [ "nofail" "noatime" ];
  };

  # 2026-08-05: the Innodisk 3TE6 (DRAM-less) failed to wake from D3cold on
  # resume ("Unable to change power state from D3cold to D0"); the kernel
  # disabled the controller and ext4 shut down until a power cycle.
  # 2026-08-10: recurred with the endpoint-only d3cold block active — during
  # s2idle the parent root port (0000:00:06.0) itself enters D3cold and cuts
  # power to the drive regardless of the endpoint's setting. Block D3cold on
  # the root port as well so the slot keeps power across suspend.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1bc0", ATTR{device}=="0x1002", ATTR{d3cold_allowed}="0"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:06.0", ATTR{d3cold_allowed}="0"
  '';

  # Rootless podman storage on the big disk instead of ~/.local/share/containers.
  # The per-user directory is created 0700 below; if /data is not mounted
  # (nofail), the root-owned mount point is not user-writable, so podman
  # fails loudly rather than filling the root fs.
  virtualisation.containers.storage.settings.storage.rootless_storage_path =
    "/data/containers/$USER";

  # User-writable homes for relocated caches (bazel output base, etc.) and
  # container storage.
  systemd.tmpfiles.rules = [
    "d /data/cache 0755 ${config.myUser.name} users -"
    "d /data/containers 0755 root root -"
    "d /data/containers/${config.myUser.name} 0700 ${config.myUser.name} users -"
  ];
}
