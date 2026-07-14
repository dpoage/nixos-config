# oerlikon has a second NVMe (1.7T, unused by the original install) that we
# dedicate to heavy, rebuildable state so the ~1T root disk stops filling up:
#   - docker's data-root (images, layers, volumes)
#   - bazel's output base (redirected via ~/.bazelrc in ./configuration.nix)
{ config, ... }:

{
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/e178627b-95a4-41f5-b029-eded5716398c";
    fsType = "ext4";
    # nofail: a dead data disk should not drop boot into emergency mode.
    options = [ "nofail" "noatime" ];
  };

  # Keep docker state on the big disk instead of /var/lib/docker.
  virtualisation.docker.daemon.settings."data-root" = "/data/docker";

  # With nofail above, an unmounted /data would otherwise let docker silently
  # recreate its data-root on the root fs. Fail docker loudly instead.
  systemd.services.docker.unitConfig.RequiresMountsFor = [ "/data" ];

  # User-writable home for relocated caches (bazel output base, etc.).
  systemd.tmpfiles.rules = [
    "d /data/cache 0755 ${config.myUser.name} users -"
  ];
}
