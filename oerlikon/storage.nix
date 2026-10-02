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
